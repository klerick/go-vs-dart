package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

type OrderRequest struct {
	UserID    int `json:"user_id"`
	ProductID int `json:"product_id"`
	Quantity  int `json:"quantity"`
}

type User struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

type OrderResponse struct {
	OrderID     int     `json:"order_id"`
	UserName    string  `json:"user_name"`
	ProductName string  `json:"product_name"`
	Quantity    int     `json:"quantity"`
	Total       float64 `json:"total"`
	CreatedAt   string  `json:"created_at"`
}

var (
	pool *pgxpool.Pool
	rdb  *redis.Client
)

func main() {
	port := os.Getenv("HTTP_PORT")
	if port == "" {
		port = "8080"
	}
	postgresURL := os.Getenv("POSTGRES_URL")
	if postgresURL == "" {
		postgresURL = "postgres://bench:bench@localhost:5432/bench"
	}
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://localhost:6379"
	}

	ctx := context.Background()

	var err error
	pool, err = pgxpool.New(ctx, postgresURL)
	if err != nil {
		log.Fatalf("unable to connect to postgres: %v", err)
	}
	defer pool.Close()

	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("unable to parse redis url: %v", err)
	}
	rdb = redis.NewClient(opts)
	defer rdb.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("POST /orders", handleCreateOrder)
	mux.HandleFunc("GET /orders/{id}", handleGetOrder)
	mux.HandleFunc("GET /orders", handleListOrders)
	mux.HandleFunc("GET /health", handleHealth)

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: mux,
	}

	done := make(chan os.Signal, 1)
	signal.Notify(done, syscall.SIGTERM, syscall.SIGINT)

	go func() {
		log.Printf("listening on :%s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	<-done
	log.Println("shutting down...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("shutdown: %v", err)
	}
	log.Println("server stopped")
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok"}`))
}

func handleCreateOrder(w http.ResponseWriter, r *http.Request) {
	var req OrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}

	if req.UserID == 0 || req.ProductID == 0 || req.Quantity <= 0 {
		writeError(w, http.StatusBadRequest, "user_id, product_id required and quantity must be > 0")
		return
	}

	ctx := r.Context()

	// Read user from Redis
	userJSON, err := rdb.Get(ctx, fmt.Sprintf("user:%d", req.UserID)).Result()
	if err != nil {
		writeError(w, http.StatusNotFound, "user not found in cache")
		return
	}

	var user User
	if err := json.Unmarshal([]byte(userJSON), &user); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to parse user data")
		return
	}

	// Read product from PostgreSQL
	var productID int
	var productName string
	var price float64
	err = pool.QueryRow(ctx, "SELECT id, name, price FROM products WHERE id = $1", req.ProductID).Scan(&productID, &productName, &price)
	if err != nil {
		writeError(w, http.StatusNotFound, "product not found")
		return
	}

	// Calculate total
	total := price * float64(req.Quantity)

	// Insert order
	var orderID int
	var createdAt time.Time
	err = pool.QueryRow(ctx,
		"INSERT INTO orders (user_id, product_id, quantity, total, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING id, created_at",
		req.UserID, req.ProductID, req.Quantity, total,
	).Scan(&orderID, &createdAt)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create order")
		return
	}

	// Invalidate cache
	rdb.Del(ctx, fmt.Sprintf("order_cache:%d", req.UserID))

	// Return response
	resp := OrderResponse{
		OrderID:     orderID,
		UserName:    user.Name,
		ProductName: productName,
		Quantity:    req.Quantity,
		Total:       total,
		CreatedAt:   createdAt.Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(resp)
}

func handleGetOrder(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid order id")
		return
	}

	ctx := r.Context()

	var orderID, userID, productID, quantity int
	var total float64
	var createdAt time.Time
	err = pool.QueryRow(ctx,
		"SELECT id, user_id, product_id, quantity, total, created_at FROM orders WHERE id = $1", id,
	).Scan(&orderID, &userID, &productID, &quantity, &total, &createdAt)
	if err != nil {
		writeError(w, http.StatusNotFound, "order not found")
		return
	}

	// Enrich with user name from Redis
	userName := ""
	userJSON, err := rdb.Get(ctx, fmt.Sprintf("user:%d", userID)).Result()
	if err == nil {
		var user User
		if json.Unmarshal([]byte(userJSON), &user) == nil {
			userName = user.Name
		}
	}

	// Enrich with product name from Postgres
	productName := ""
	pool.QueryRow(ctx, "SELECT name FROM products WHERE id = $1", productID).Scan(&productName)

	resp := OrderResponse{
		OrderID:     orderID,
		UserName:    userName,
		ProductName: productName,
		Quantity:    quantity,
		Total:       total,
		CreatedAt:   createdAt.Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

type OrderListResponse struct {
	Orders []OrderResponse `json:"orders"`
	Count  int             `json:"count"`
}

func handleListOrders(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	userIDStr := q.Get("user_id")
	if userIDStr == "" {
		writeError(w, http.StatusBadRequest, "user_id is required")
		return
	}
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user_id")
		return
	}

	limit := 20
	if l := q.Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	offset := 0
	if o := q.Get("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	ctx := r.Context()

	rows, err := pool.Query(ctx,
		"SELECT o.id, o.product_id, o.quantity, o.total, o.created_at, p.name FROM orders o JOIN products p ON p.id = o.product_id WHERE o.user_id = $1 ORDER BY o.created_at DESC LIMIT $2 OFFSET $3",
		userID, limit, offset,
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	defer rows.Close()

	// Get user name from Redis
	userName := ""
	userJSON, err := rdb.Get(ctx, fmt.Sprintf("user:%d", userID)).Result()
	if err == nil {
		var user User
		if json.Unmarshal([]byte(userJSON), &user) == nil {
			userName = user.Name
		}
	}

	var orders []OrderResponse
	for rows.Next() {
		var oid, productID, qty int
		var tot float64
		var ca time.Time
		var pname string
		if err := rows.Scan(&oid, &productID, &qty, &tot, &ca, &pname); err != nil {
			continue
		}
		orders = append(orders, OrderResponse{
			OrderID:     oid,
			UserName:    userName,
			ProductName: pname,
			Quantity:    qty,
			Total:       tot,
			CreatedAt:   ca.Format(time.RFC3339),
		})
	}

	if orders == nil {
		orders = []OrderResponse{}
	}

	resp := OrderListResponse{
		Orders: orders,
		Count:  len(orders),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}