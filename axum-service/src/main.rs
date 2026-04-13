use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    Json, Router,
};
use chrono::{DateTime, Utc};
use deadpool_postgres::Pool;
use redis::AsyncCommands;
use serde::{Deserialize, Serialize};
use std::env;
use std::fmt::Write;
use std::net::SocketAddr;
use tokio::net::TcpListener;
use tokio::signal;
use tokio_postgres::NoTls;

#[cfg(not(target_env = "msvc"))]
#[global_allocator]
static GLOBAL: tikv_jemallocator::Jemalloc = tikv_jemallocator::Jemalloc;

#[derive(Clone)]
struct AppState {
    pg: Pool,
    redis: redis::aio::ConnectionManager,
}

#[derive(Deserialize)]
struct OrderRequest {
    user_id: i32,
    product_id: i32,
    quantity: i32,
}

#[derive(Serialize, Deserialize)]
struct User {
    id: i32,
    name: String,
    email: String,
}

#[derive(Serialize)]
struct OrderResponse {
    order_id: i32,
    user_name: String,
    product_name: String,
    quantity: i32,
    total: f64,
    created_at: String,
}

#[derive(Serialize)]
struct OrderListResponse {
    orders: Vec<OrderResponse>,
    count: usize,
}

#[derive(Serialize)]
struct ErrorBody<'a> {
    error: &'a str,
}

#[derive(Serialize)]
struct HealthBody {
    status: &'static str,
}

#[derive(Deserialize)]
struct ListOrdersQuery {
    user_id: Option<String>,
    limit: Option<String>,
    offset: Option<String>,
}

fn error_json(msg: &str) -> Json<ErrorBody<'_>> {
    Json(ErrorBody { error: msg })
}

fn redis_key(prefix: &str, id: i32) -> String {
    let mut key = String::with_capacity(prefix.len() + 10);
    key.push_str(prefix);
    let _ = write!(key, "{}", itoa::Buffer::new().format(id));
    key
}

async fn handle_health() -> impl IntoResponse {
    Json(HealthBody { status: "ok" })
}

async fn handle_create_order(
    State(state): State<AppState>,
    body: axum::body::Bytes,
) -> Response {
    let req: OrderRequest = match serde_json::from_slice(&body) {
        Ok(r) => r,
        Err(_) => {
            return (StatusCode::BAD_REQUEST, error_json("invalid json body")).into_response()
        }
    };

    if req.user_id == 0 || req.product_id == 0 || req.quantity <= 0 {
        return (
            StatusCode::BAD_REQUEST,
            error_json("user_id, product_id required and quantity must be > 0"),
        )
            .into_response();
    }

    // Read user from Redis
    let mut redis = state.redis.clone();
    let user_json: Option<String> = match redis.get(redis_key("user:", req.user_id)).await {
        Ok(v) => v,
        Err(_) => None,
    };

    let mut user_json = match user_json {
        Some(v) => v,
        None => {
            return (
                StatusCode::NOT_FOUND,
                error_json("user not found in cache"),
            )
                .into_response()
        }
    };

    let user: User = match unsafe { simd_json::from_str(&mut user_json) } {
        Ok(u) => u,
        Err(_) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                error_json("failed to parse user data"),
            )
                .into_response()
        }
    };

    // Get a Postgres connection from the pool
    let pg = match state.pg.get().await {
        Ok(c) => c,
        Err(_) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                error_json("database unavailable"),
            )
                .into_response()
        }
    };

    // Read product (with cached prepared statement)
    let stmt = pg
        .prepare_cached("SELECT id, name, price::float8 FROM products WHERE id = $1")
        .await
        .unwrap();
    let product_row = match pg.query_opt(&stmt, &[&req.product_id]).await {
        Ok(Some(row)) => row,
        _ => return (StatusCode::NOT_FOUND, error_json("product not found")).into_response(),
    };

    let product_name: &str = product_row.get(1);
    let price: f64 = product_row.get(2);
    let total = price * req.quantity as f64;

    // Insert order (with cached prepared statement)
    let stmt = pg
        .prepare_cached(
            "INSERT INTO orders (user_id, product_id, quantity, total, created_at) \
             VALUES ($1, $2, $3, $4::float8, NOW()) RETURNING id, created_at",
        )
        .await
        .unwrap();
    let insert_row = match pg
        .query_one(&stmt, &[&req.user_id, &req.product_id, &req.quantity, &total])
        .await
    {
        Ok(row) => row,
        Err(_) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                error_json("failed to create order"),
            )
                .into_response()
        }
    };

    let order_id: i32 = insert_row.get(0);
    let created_at: DateTime<Utc> = insert_row.get(1);

    // Invalidate cache
    let _: Result<i32, _> = redis.del(redis_key("order_cache:", req.user_id)).await;

    let resp = OrderResponse {
        order_id,
        user_name: user.name,
        product_name: product_name.to_owned(),
        quantity: req.quantity,
        total,
        created_at: created_at.to_rfc3339(),
    };

    (StatusCode::CREATED, Json(resp)).into_response()
}

async fn handle_get_order(State(state): State<AppState>, Path(id): Path<i32>) -> Response {
    let pg = match state.pg.get().await {
        Ok(c) => c,
        Err(_) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                error_json("database unavailable"),
            )
                .into_response()
        }
    };

    let stmt = pg
        .prepare_cached(
            "SELECT id, user_id, product_id, quantity, total::float8, created_at \
             FROM orders WHERE id = $1",
        )
        .await
        .unwrap();
    let row = match pg.query_opt(&stmt, &[&id]).await {
        Ok(Some(row)) => row,
        _ => return (StatusCode::NOT_FOUND, error_json("order not found")).into_response(),
    };

    let user_id: i32 = row.get(1);
    let product_id: i32 = row.get(2);
    let quantity: i32 = row.get(3);
    let total: f64 = row.get(4);
    let created_at: DateTime<Utc> = row.get(5);

    // Enrich with user name from Redis
    let mut redis = state.redis.clone();
    let mut user_name = String::new();
    if let Ok(Some(mut user_json)) = redis
        .get::<_, Option<String>>(redis_key("user:", user_id))
        .await
    {
        if let Ok(user) = unsafe { simd_json::from_str::<User>(&mut user_json) } {
            user_name = user.name;
        }
    }

    // Enrich with product name from Postgres
    let mut product_name = String::new();
    let stmt = pg
        .prepare_cached("SELECT name FROM products WHERE id = $1")
        .await
        .unwrap();
    if let Ok(Some(row)) = pg.query_opt(&stmt, &[&product_id]).await {
        product_name = row.get::<_, &str>(0).to_owned();
    }

    let resp = OrderResponse {
        order_id: id,
        user_name,
        product_name,
        quantity,
        total,
        created_at: created_at.to_rfc3339(),
    };

    Json(resp).into_response()
}

async fn handle_list_orders(
    State(state): State<AppState>,
    Query(params): Query<ListOrdersQuery>,
) -> Response {
    let user_id_str = match params.user_id {
        Some(ref s) if !s.is_empty() => s.clone(),
        _ => {
            return (StatusCode::BAD_REQUEST, error_json("user_id is required")).into_response()
        }
    };

    let user_id: i32 = match user_id_str.parse() {
        Ok(id) => id,
        Err(_) => {
            return (StatusCode::BAD_REQUEST, error_json("invalid user_id")).into_response()
        }
    };

    let mut limit: i64 = 20;
    if let Some(ref l) = params.limit {
        if let Ok(parsed) = l.parse::<i64>() {
            if parsed > 0 && parsed <= 100 {
                limit = parsed;
            }
        }
    }

    let mut offset: i64 = 0;
    if let Some(ref o) = params.offset {
        if let Ok(parsed) = o.parse::<i64>() {
            if parsed >= 0 {
                offset = parsed;
            }
        }
    }

    // Get user name from Redis
    let mut redis = state.redis.clone();
    let mut user_name = String::new();
    if let Ok(Some(mut user_json)) = redis
        .get::<_, Option<String>>(redis_key("user:", user_id))
        .await
    {
        if let Ok(user) = unsafe { simd_json::from_str::<User>(&mut user_json) } {
            user_name = user.name;
        }
    }

    let pg = match state.pg.get().await {
        Ok(c) => c,
        Err(_) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                error_json("query failed"),
            )
                .into_response()
        }
    };

    let stmt = pg
        .prepare_cached(
            "SELECT o.id, o.product_id, o.quantity, o.total::float8, o.created_at, p.name \
             FROM orders o JOIN products p ON p.id = o.product_id \
             WHERE o.user_id = $1 ORDER BY o.created_at DESC LIMIT $2 OFFSET $3",
        )
        .await
        .unwrap();
    let rows = match pg.query(&stmt, &[&user_id, &limit, &offset]).await {
        Ok(rows) => rows,
        Err(_) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                error_json("query failed"),
            )
                .into_response()
        }
    };

    let orders: Vec<OrderResponse> = rows
        .iter()
        .map(|row| {
            let oid: i32 = row.get(0);
            let qty: i32 = row.get(2);
            let tot: f64 = row.get(3);
            let ca: DateTime<Utc> = row.get(4);
            let pname: &str = row.get(5);
            OrderResponse {
                order_id: oid,
                user_name: user_name.clone(),
                product_name: pname.to_owned(),
                quantity: qty,
                total: tot,
                created_at: ca.to_rfc3339(),
            }
        })
        .collect();

    let count = orders.len();
    Json(OrderListResponse { orders, count }).into_response()
}

async fn run() {
    let port: u16 = env::var("HTTP_PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(8080);
    let postgres_url = env::var("POSTGRES_URL")
        .unwrap_or_else(|_| "postgres://bench:bench@localhost:5432/bench".to_string());
    let redis_url =
        env::var("REDIS_URL").unwrap_or_else(|_| "redis://localhost:6379".to_string());

    // Postgres via deadpool + tokio-postgres
    let pg_config: tokio_postgres::Config = postgres_url.parse().expect("invalid postgres url");
    let mgr = deadpool_postgres::Manager::new(pg_config, NoTls);
    let pg = Pool::builder(mgr)
        .max_size(4)
        .build()
        .expect("unable to create postgres pool");

    // Redis
    let redis_client =
        redis::Client::open(redis_url.as_str()).expect("unable to parse redis url");
    let redis_conn = redis::aio::ConnectionManager::new(redis_client)
        .await
        .expect("unable to connect to redis");

    let state = AppState {
        pg,
        redis: redis_conn,
    };

    let app = Router::new()
        .route("/health", get(handle_health))
        .route("/orders", get(handle_list_orders).post(handle_create_order))
        .route("/orders/{id}", get(handle_get_order))
        .with_state(state);

    // Create listener with TCP_NODELAY
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let socket = socket2::Socket::new(
        socket2::Domain::IPV4,
        socket2::Type::STREAM,
        Some(socket2::Protocol::TCP),
    )
    .expect("unable to create socket");
    socket.set_reuse_address(true).unwrap();
    socket.set_nodelay(true).unwrap();
    socket.bind(&addr.into()).expect("unable to bind");
    socket.listen(1024).expect("unable to listen");
    socket.set_nonblocking(true).unwrap();
    let listener = TcpListener::from_std(std::net::TcpListener::from(socket))
        .expect("unable to wrap listener");

    println!("listening on :{}", port);

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .expect("server error");

    println!("server stopped");
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    println!("shutting down...");
}

fn main() {
    let workers: usize = env::var("WORKER_THREADS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1);

    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(workers)
        .enable_io()
        .enable_time()
        .build()
        .unwrap()
        .block_on(run());
}
