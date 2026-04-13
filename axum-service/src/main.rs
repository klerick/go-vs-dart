use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    Json, Router,
};
use chrono::{DateTime, Utc};
use redis::AsyncCommands;
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgPoolOptions;
use sqlx::{PgPool, Row};
use std::env;
use tokio::net::TcpListener;
use tokio::signal;

#[derive(Clone)]
struct AppState {
    pg: PgPool,
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

#[derive(Deserialize)]
struct ListOrdersQuery {
    user_id: Option<String>,
    limit: Option<String>,
    offset: Option<String>,
}

fn error_json(msg: &str) -> Json<serde_json::Value> {
    Json(serde_json::json!({"error": msg}))
}

async fn handle_health() -> impl IntoResponse {
    Json(serde_json::json!({"status": "ok"}))
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
    let user_json: Option<String> = match redis.get(format!("user:{}", req.user_id)).await {
        Ok(v) => v,
        Err(_) => None,
    };

    let user_json = match user_json {
        Some(v) => v,
        None => {
            return (
                StatusCode::NOT_FOUND,
                error_json("user not found in cache"),
            )
                .into_response()
        }
    };

    let user: User = match serde_json::from_str(&user_json) {
        Ok(u) => u,
        Err(_) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                error_json("failed to parse user data"),
            )
                .into_response()
        }
    };

    // Read product from PostgreSQL
    let product_row = match sqlx::query(
        "SELECT id, name, price::float8 FROM products WHERE id = $1",
    )
    .bind(req.product_id)
    .fetch_optional(&state.pg)
    .await
    {
        Ok(Some(row)) => row,
        _ => return (StatusCode::NOT_FOUND, error_json("product not found")).into_response(),
    };

    let product_name: String = product_row.get("name");
    let price: f64 = product_row.get("price");
    let total = price * req.quantity as f64;

    // Insert order
    let insert_row = match sqlx::query(
        "INSERT INTO orders (user_id, product_id, quantity, total, created_at) \
         VALUES ($1, $2, $3, $4, NOW()) RETURNING id, created_at",
    )
    .bind(req.user_id)
    .bind(req.product_id)
    .bind(req.quantity)
    .bind(total)
    .fetch_one(&state.pg)
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

    let order_id: i32 = insert_row.get("id");
    let created_at: DateTime<Utc> = insert_row.get("created_at");

    // Invalidate cache
    let _: Result<i32, _> = redis.del(format!("order_cache:{}", req.user_id)).await;

    let resp = OrderResponse {
        order_id,
        user_name: user.name,
        product_name,
        quantity: req.quantity,
        total,
        created_at: created_at.to_rfc3339(),
    };

    (StatusCode::CREATED, Json(resp)).into_response()
}

async fn handle_get_order(State(state): State<AppState>, Path(id): Path<i32>) -> Response {
    let row = match sqlx::query(
        "SELECT id, user_id, product_id, quantity, total::float8, created_at \
         FROM orders WHERE id = $1",
    )
    .bind(id)
    .fetch_optional(&state.pg)
    .await
    {
        Ok(Some(row)) => row,
        _ => return (StatusCode::NOT_FOUND, error_json("order not found")).into_response(),
    };

    let user_id: i32 = row.get("user_id");
    let product_id: i32 = row.get("product_id");
    let quantity: i32 = row.get("quantity");
    let total: f64 = row.get("total");
    let created_at: DateTime<Utc> = row.get("created_at");

    // Enrich with user name from Redis
    let mut redis = state.redis.clone();
    let mut user_name = String::new();
    if let Ok(Some(user_json)) = redis
        .get::<_, Option<String>>(format!("user:{}", user_id))
        .await
    {
        if let Ok(user) = serde_json::from_str::<User>(&user_json) {
            user_name = user.name;
        }
    }

    // Enrich with product name from Postgres
    let mut product_name = String::new();
    if let Ok(Some(row)) = sqlx::query("SELECT name FROM products WHERE id = $1")
        .bind(product_id)
        .fetch_optional(&state.pg)
        .await
    {
        product_name = row.get("name");
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
    if let Ok(Some(user_json)) = redis
        .get::<_, Option<String>>(format!("user:{}", user_id))
        .await
    {
        if let Ok(user) = serde_json::from_str::<User>(&user_json) {
            user_name = user.name;
        }
    }

    let rows = match sqlx::query(
        "SELECT o.id, o.product_id, o.quantity, o.total::float8, o.created_at, p.name \
         FROM orders o JOIN products p ON p.id = o.product_id \
         WHERE o.user_id = $1 ORDER BY o.created_at DESC LIMIT $2 OFFSET $3",
    )
    .bind(user_id)
    .bind(limit)
    .bind(offset)
    .fetch_all(&state.pg)
    .await
    {
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
            let pname: String = row.get(5);
            OrderResponse {
                order_id: oid,
                user_name: user_name.clone(),
                product_name: pname,
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
    let port = env::var("HTTP_PORT").unwrap_or_else(|_| "8080".to_string());
    let postgres_url = env::var("POSTGRES_URL")
        .unwrap_or_else(|_| "postgres://bench:bench@localhost:5432/bench".to_string());
    let redis_url =
        env::var("REDIS_URL").unwrap_or_else(|_| "redis://localhost:6379".to_string());

    let pg = PgPoolOptions::new()
        .max_connections(10)
        .connect(&postgres_url)
        .await
        .expect("unable to connect to postgres");

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

    let listener = TcpListener::bind(format!("0.0.0.0:{}", port))
        .await
        .expect("unable to bind");

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
    // Default to 1 worker thread to match Go's GOMAXPROCS=1.
    // Override with WORKER_THREADS env var if needed.
    let workers: usize = env::var("WORKER_THREADS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1);

    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(workers)
        .enable_all()
        .build()
        .unwrap()
        .block_on(run());
}
