use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    Router,
};
use chrono::{DateTime, Datelike, Timelike, Utc};
use deadpool_postgres::Pool;
use deadpool_redis::redis::{aio::MultiplexedConnection, AsyncCommands};
use simd_json_derive::Deserialize as SimdDeserialize;
use simd_json_derive::Serialize as SimdSerialize;
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
    redis: MultiplexedConnection,
}

#[derive(simd_json_derive::Deserialize)]
struct OrderRequest {
    user_id: i32,
    product_id: i32,
    quantity: i32,
}

#[derive(simd_json_derive::Deserialize)]
struct User {
    #[allow(dead_code)]
    id: i32,
    name: String,
    #[allow(dead_code)]
    email: String,
}

#[derive(simd_json_derive::Serialize)]
struct OrderResponse {
    order_id: i32,
    user_name: String,
    product_name: String,
    quantity: i32,
    total: f64,
    created_at: String,
}

#[derive(simd_json_derive::Serialize)]
struct OrderListResponse {
    orders: Vec<OrderResponse>,
    count: usize,
}

#[derive(simd_json_derive::Serialize)]
struct ErrorBody<'a> {
    error: &'a str,
}

#[derive(simd_json_derive::Serialize)]
struct HealthBody {
    status: &'static str,
}

#[derive(serde::Deserialize)]
struct ListOrdersQuery {
    user_id: Option<String>,
    limit: Option<String>,
    offset: Option<String>,
}

fn json_response<T: SimdSerialize>(status: StatusCode, body: &T) -> Response {
    (
        status,
        [("content-type", "application/json")],
        body.json_vec().unwrap(),
    )
        .into_response()
}

fn redis_key(prefix: &str, id: i32) -> String {
    let mut key = String::with_capacity(prefix.len() + 10);
    key.push_str(prefix);
    let _ = write!(key, "{}", itoa::Buffer::new().format(id));
    key
}

async fn rget(conn: &MultiplexedConnection, key: String) -> Option<String> {
    conn.clone().get(key).await.ok()?
}

async fn rdel(conn: &MultiplexedConnection, key: String) {
    let _: Result<i32, _> = conn.clone().del(key).await;
}

fn fmt_ts(dt: DateTime<Utc>) -> String {
    let mut buf = String::with_capacity(25);
    let _ = write!(
        buf,
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}+00:00",
        dt.year(),
        dt.month(),
        dt.day(),
        dt.hour(),
        dt.minute(),
        dt.second()
    );
    buf
}

async fn handle_health() -> Response {
    json_response(StatusCode::OK, &HealthBody { status: "ok" })
}

async fn handle_create_order(
    State(state): State<AppState>,
    body: axum::body::Bytes,
) -> Response {
    let mut body_buf = body.to_vec();
    let req: OrderRequest = match OrderRequest::from_slice(&mut body_buf) {
        Ok(r) => r,
        Err(_) => {
            return json_response(
                StatusCode::BAD_REQUEST,
                &ErrorBody {
                    error: "invalid json body",
                },
            )
        }
    };

    if req.user_id == 0 || req.product_id == 0 || req.quantity <= 0 {
        return json_response(
            StatusCode::BAD_REQUEST,
            &ErrorBody {
                error: "user_id, product_id required and quantity must be > 0",
            },
        );
    }

    // Concurrent: Redis user lookup + Postgres product lookup
    let product_id = req.product_id;
    let (user_res, product_res) = tokio::join!(
        rget(&state.redis, redis_key("user:", req.user_id)),
        async {
            let pg = match state.pg.get().await {
                Ok(c) => c,
                Err(_) => {
                    return Err((StatusCode::INTERNAL_SERVER_ERROR, "database unavailable"))
                }
            };
            let stmt = pg
                .prepare_cached("SELECT name, price::float8 FROM products WHERE id = $1")
                .await
                .unwrap();
            match pg.query_opt(&stmt, &[&product_id]).await {
                Ok(Some(row)) => {
                    let name: String = row.get::<_, &str>(0).to_owned();
                    let price: f64 = row.get(1);
                    Ok((name, price))
                }
                _ => Err((StatusCode::NOT_FOUND, "product not found")),
            }
        }
    );

    let mut user_json = match user_res {
        Some(v) => v,
        None => {
            return json_response(
                StatusCode::NOT_FOUND,
                &ErrorBody {
                    error: "user not found in cache",
                },
            )
        }
    };

    let user: User = match unsafe { User::from_str(&mut user_json) } {
        Ok(u) => u,
        Err(_) => {
            return json_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                &ErrorBody {
                    error: "failed to parse user data",
                },
            )
        }
    };

    let (product_name, price) = match product_res {
        Ok(v) => v,
        Err((status, msg)) => return json_response(status, &ErrorBody { error: msg }),
    };

    let total = price * req.quantity as f64;

    // Insert order — checkout pg, query, return to pool
    let (order_id, created_at) = {
        let pg = match state.pg.get().await {
            Ok(c) => c,
            Err(_) => {
                return json_response(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    &ErrorBody {
                        error: "failed to create order",
                    },
                )
            }
        };
        let stmt = pg
            .prepare_cached(
                "INSERT INTO orders (user_id, product_id, quantity, total, created_at) \
                 VALUES ($1, $2, $3, $4::float8, NOW()) RETURNING id, created_at",
            )
            .await
            .unwrap();
        match pg
            .query_one(&stmt, &[&req.user_id, &req.product_id, &req.quantity, &total])
            .await
        {
            Ok(row) => {
                let oid: i32 = row.get(0);
                let ca: DateTime<Utc> = row.get(1);
                (oid, ca)
            }
            Err(_) => {
                return json_response(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    &ErrorBody {
                        error: "failed to create order",
                    },
                )
            }
        }
    }; // pg returned to pool

    // Invalidate cache
    rdel(&state.redis, redis_key("order_cache:", req.user_id)).await;

    json_response(
        StatusCode::CREATED,
        &OrderResponse {
            order_id,
            user_name: user.name,
            product_name,
            quantity: req.quantity,
            total,
            created_at: fmt_ts(created_at),
        },
    )
}

async fn handle_get_order(State(state): State<AppState>, Path(id): Path<i32>) -> Response {
    // Query order — checkout pg, query, return to pool
    let (user_id, product_id, quantity, total, created_at) = {
        let pg = match state.pg.get().await {
            Ok(c) => c,
            Err(_) => {
                return json_response(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    &ErrorBody {
                        error: "database unavailable",
                    },
                )
            }
        };
        let stmt = pg
            .prepare_cached(
                "SELECT user_id, product_id, quantity, total::float8, created_at \
                 FROM orders WHERE id = $1",
            )
            .await
            .unwrap();
        match pg.query_opt(&stmt, &[&id]).await {
            Ok(Some(row)) => {
                let uid: i32 = row.get(0);
                let pid: i32 = row.get(1);
                let qty: i32 = row.get(2);
                let tot: f64 = row.get(3);
                let ca: DateTime<Utc> = row.get(4);
                (uid, pid, qty, tot, ca)
            }
            _ => {
                return json_response(
                    StatusCode::NOT_FOUND,
                    &ErrorBody {
                        error: "order not found",
                    },
                )
            }
        }
    }; // pg returned to pool

    // Concurrent: Redis user enrichment + Postgres product enrichment
    let (user_name, product_res) = tokio::join!(
        async {
            if let Some(mut user_json) = rget(&state.redis, redis_key("user:", user_id)).await {
                if let Ok(user) = unsafe { User::from_str(&mut user_json) } {
                    return user.name;
                }
            }
            String::new()
        },
        async {
            let pg = match state.pg.get().await {
                Ok(c) => c,
                Err(_) => return Err("database unavailable"),
            };
            let stmt = pg
                .prepare_cached("SELECT name FROM products WHERE id = $1")
                .await
                .unwrap();
            let mut name = String::new();
            if let Ok(Some(row)) = pg.query_opt(&stmt, &[&product_id]).await {
                name = row.get::<_, &str>(0).to_owned();
            }
            Ok(name)
        }
    );

    let product_name = match product_res {
        Ok(name) => name,
        Err(msg) => {
            return json_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                &ErrorBody { error: msg },
            )
        }
    };

    json_response(
        StatusCode::OK,
        &OrderResponse {
            order_id: id,
            user_name,
            product_name,
            quantity,
            total,
            created_at: fmt_ts(created_at),
        },
    )
}

async fn handle_list_orders(
    State(state): State<AppState>,
    Query(params): Query<ListOrdersQuery>,
) -> Response {
    let user_id_str = match params.user_id {
        Some(ref s) if !s.is_empty() => s.clone(),
        _ => {
            return json_response(
                StatusCode::BAD_REQUEST,
                &ErrorBody {
                    error: "user_id is required",
                },
            )
        }
    };

    let user_id: i32 = match user_id_str.parse() {
        Ok(id) => id,
        Err(_) => {
            return json_response(
                StatusCode::BAD_REQUEST,
                &ErrorBody {
                    error: "invalid user_id",
                },
            )
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

    // Concurrent: Redis user lookup + Postgres orders query
    let (user_name, rows_res) = tokio::join!(
        async {
            if let Some(mut user_json) = rget(&state.redis, redis_key("user:", user_id)).await {
                if let Ok(user) = unsafe { User::from_str(&mut user_json) } {
                    return user.name;
                }
            }
            String::new()
        },
        async {
            let pg = match state.pg.get().await {
                Ok(c) => c,
                Err(_) => return Err("query failed"),
            };
            let stmt = pg
                .prepare_cached(
                    "SELECT o.id, o.product_id, o.quantity, o.total::float8, o.created_at, p.name \
                     FROM orders o JOIN products p ON p.id = o.product_id \
                     WHERE o.user_id = $1 ORDER BY o.created_at DESC LIMIT $2 OFFSET $3",
                )
                .await
                .unwrap();
            pg.query(&stmt, &[&user_id, &limit, &offset])
                .await
                .map_err(|_| "query failed")
        }
    );

    let rows = match rows_res {
        Ok(r) => r,
        Err(msg) => {
            return json_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                &ErrorBody { error: msg },
            )
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
                created_at: fmt_ts(ca),
            }
        })
        .collect();

    let count = orders.len();
    json_response(StatusCode::OK, &OrderListResponse { orders, count })
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

    // Postgres via deadpool + tokio-postgres (pool matches Go's pgxpool: max(4, num_cpus))
    let pg_pool_size = std::cmp::max(4, num_cpus::get());
    let pg_config: tokio_postgres::Config = postgres_url.parse().expect("invalid postgres url");
    let mgr = deadpool_postgres::Manager::new(pg_config, NoTls);
    let pg = Pool::builder(mgr)
        .max_size(pg_pool_size)
        .build()
        .expect("unable to create postgres pool");

    // Redis via deadpool — take the underlying MultiplexedConnection, clone per handler
    let redis_cfg = deadpool_redis::Config::from_url(&redis_url);
    let redis_pool = redis_cfg
        .builder()
        .expect("invalid redis config")
        .max_size(1)
        .build()
        .expect("unable to create redis pool");
    let redis_conn = deadpool_redis::Connection::take(redis_pool.get().await.unwrap());

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
