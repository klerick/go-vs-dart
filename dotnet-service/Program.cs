using System.Text.Json;
using Npgsql;
using StackExchange.Redis;

var port = Environment.GetEnvironmentVariable("HTTP_PORT") ?? "8080";
var postgresUrl = Environment.GetEnvironmentVariable("POSTGRES_URL") ?? "postgres://bench:bench@localhost:5432/bench";
var redisUrl = Environment.GetEnvironmentVariable("REDIS_URL") ?? "redis://localhost:6379";

var pgUri = new Uri(postgresUrl);
var userInfo = pgUri.UserInfo.Split(':');
var connStr = $"Host={pgUri.Host};Port={pgUri.Port};Database={pgUri.AbsolutePath.TrimStart('/')};Username={userInfo[0]};Password={userInfo[1]};Maximum Pool Size=10;SSL Mode=Disable";
var pgDataSource = NpgsqlDataSource.Create(connStr);

var redisUri = new Uri(redisUrl);
var redis = await ConnectionMultiplexer.ConnectAsync($"{redisUri.Host}:{redisUri.Port}");
var rdb = redis.GetDatabase();

var builder = WebApplication.CreateSlimBuilder(args);
builder.WebHost.ConfigureKestrel(o => o.ListenAnyIP(int.Parse(port)));
builder.Logging.SetMinimumLevel(LogLevel.Warning);
var app = builder.Build();

app.MapGet("/health", () => Results.Json(new { status = "ok" }));

app.MapPost("/orders", async (HttpRequest request) =>
{
    JsonElement json;
    try { json = await JsonSerializer.DeserializeAsync<JsonElement>(request.Body); }
    catch { return Results.Json(new { error = "invalid JSON" }, statusCode: 400); }

    if (!json.TryGetProperty("user_id", out var uid) || !json.TryGetProperty("product_id", out var pid) || !json.TryGetProperty("quantity", out var qty))
        return Results.Json(new { error = "user_id, product_id, and quantity are required" }, statusCode: 400);

    var userId = uid.GetInt32();
    var productId = pid.GetInt32();
    var quantity = qty.GetInt32();
    if (quantity <= 0) return Results.Json(new { error = "quantity must be > 0" }, statusCode: 400);

    var userRaw = await rdb.StringGetAsync($"user:{userId}");
    if (userRaw.IsNull) return Results.Json(new { error = "user not found" }, statusCode: 404);
    var user = JsonDocument.Parse(userRaw.ToString()).RootElement;

    await using var conn = await pgDataSource.OpenConnectionAsync();

    string productName;
    decimal price;
    {
        await using var cmd = new NpgsqlCommand("SELECT name, price FROM products WHERE id = $1", conn);
        cmd.Parameters.AddWithValue(productId);
        await using var rdr = await cmd.ExecuteReaderAsync();
        if (!await rdr.ReadAsync()) return Results.Json(new { error = "product not found" }, statusCode: 404);
        productName = rdr.GetString(0);
        price = rdr.GetDecimal(1);
    }

    var total = price * quantity;

    int orderId;
    DateTime createdAt;
    {
        await using var cmd = new NpgsqlCommand("INSERT INTO orders (user_id, product_id, quantity, total, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING id, created_at", conn);
        cmd.Parameters.AddWithValue(userId);
        cmd.Parameters.AddWithValue(productId);
        cmd.Parameters.AddWithValue(quantity);
        cmd.Parameters.AddWithValue(total);
        await using var rdr = await cmd.ExecuteReaderAsync();
        await rdr.ReadAsync();
        orderId = rdr.GetInt32(0);
        createdAt = rdr.GetDateTime(1);
    }

    await rdb.KeyDeleteAsync($"order_cache:{userId}");

    return Results.Json(new
    {
        order_id = orderId,
        user_name = user.GetProperty("name").GetString(),
        product_name = productName,
        quantity,
        total = (double)total,
        created_at = createdAt.ToString("o")
    }, statusCode: 201);
});

app.MapGet("/orders/{id:int}", async (int id) =>
{
    await using var conn = await pgDataSource.OpenConnectionAsync();

    int userId, productId, quantity;
    double total;
    DateTime createdAt;
    {
        await using var cmd = new NpgsqlCommand("SELECT user_id, product_id, quantity, total, created_at FROM orders WHERE id = $1", conn);
        cmd.Parameters.AddWithValue(id);
        await using var rdr = await cmd.ExecuteReaderAsync();
        if (!await rdr.ReadAsync()) return Results.Json(new { error = "order not found" }, statusCode: 404);
        userId = rdr.GetInt32(0);
        productId = rdr.GetInt32(1);
        quantity = rdr.GetInt32(2);
        total = (double)rdr.GetDecimal(3);
        createdAt = rdr.GetDateTime(4);
    }

    var userName = "";
    var userRaw = await rdb.StringGetAsync($"user:{userId}");
    if (!userRaw.IsNull) userName = JsonDocument.Parse(userRaw.ToString()).RootElement.GetProperty("name").GetString() ?? "";

    var productName = "";
    {
        await using var cmd = new NpgsqlCommand("SELECT name FROM products WHERE id = $1", conn);
        cmd.Parameters.AddWithValue(productId);
        await using var rdr = await cmd.ExecuteReaderAsync();
        if (await rdr.ReadAsync()) productName = rdr.GetString(0);
    }

    return Results.Json(new { order_id = id, user_name = userName, product_name = productName, quantity, total, created_at = createdAt.ToString("o") });
});

app.MapGet("/orders", async (HttpRequest request) =>
{
    var userIdStr = request.Query["user_id"].FirstOrDefault();
    if (userIdStr == null || !int.TryParse(userIdStr, out var userId))
        return Results.Json(new { error = "user_id is required" }, statusCode: 400);

    var limit = 20;
    if (request.Query.ContainsKey("limit") && int.TryParse(request.Query["limit"], out var l) && l > 0 && l <= 100) limit = l;
    var offset = 0;
    if (request.Query.ContainsKey("offset") && int.TryParse(request.Query["offset"], out var o) && o >= 0) offset = o;

    var userName = "";
    var userRaw = await rdb.StringGetAsync($"user:{userId}");
    if (!userRaw.IsNull) userName = JsonDocument.Parse(userRaw.ToString()).RootElement.GetProperty("name").GetString() ?? "";

    await using var conn = await pgDataSource.OpenConnectionAsync();
    await using var cmd = new NpgsqlCommand(
        "SELECT o.id, o.product_id, o.quantity, o.total, o.created_at, p.name FROM orders o JOIN products p ON p.id = o.product_id WHERE o.user_id = $1 ORDER BY o.created_at DESC LIMIT $2 OFFSET $3", conn);
    cmd.Parameters.AddWithValue(userId);
    cmd.Parameters.AddWithValue(limit);
    cmd.Parameters.AddWithValue(offset);
    await using var rdr = await cmd.ExecuteReaderAsync();

    var orders = new List<object>();
    while (await rdr.ReadAsync())
    {
        orders.Add(new
        {
            order_id = rdr.GetInt32(0),
            user_name = userName,
            product_name = rdr.GetString(5),
            quantity = rdr.GetInt32(2),
            total = (double)rdr.GetDecimal(3),
            created_at = rdr.GetDateTime(4).ToString("o")
        });
    }

    return Results.Json(new { orders, count = orders.Count });
});

Console.WriteLine($"Server listening on port {port}");
app.Run();
