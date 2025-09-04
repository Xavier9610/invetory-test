using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Transactions.Application.Dtos;
using Transactions.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

// Services
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
builder.Services.AddScoped<ITransactionRepository, TransactionRepository>();

//to debug
builder.Services.AddCors(opt =>
{
    opt.AddPolicy("dev", p => p
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowAnyOrigin()
    );
});

//

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();
// Usa CORS antes de mapear endpoints
app.UseCors("dev");

// Health
app.MapGet("/", () => Results.Ok("Transactions.Api up"));

// Routes
var group = app.MapGroup("/api/transactions");

app.UseCors("dev");
// Create
group.MapPost("/", async ([FromBody] TransactionCreateDto dto, [FromServices] ITransactionRepository repo, CancellationToken ct) =>
{
    if (dto.Quantity <= 0 || dto.UnitPrice < 0) return Results.BadRequest(new { error = "Invalid quantity or unit price." });

    try
    {
        var id = await repo.AddAsync(dto, ct);
        var created = await repo.GetByIdAsync(id, ct);
        return Results.Created($"/api/transactions/{id}", created);
    }
    catch (SqlException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

// Update
group.MapPut("/{id:long}", async (long id, [FromBody] TransactionUpdateDto dto, [FromServices] ITransactionRepository repo, CancellationToken ct) =>
{
    try
    {
        await repo.UpdateAsync(id, dto, ct);
        var updated = await repo.GetByIdAsync(id, ct);
        return updated is null ? Results.NotFound() : Results.Ok(updated);
    }
    catch (InvalidOperationException)
    {
        return Results.NotFound();
    }
    catch (SqlException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

// Delete
group.MapDelete("/{id:long}", async (long id, [FromServices] ITransactionRepository repo, CancellationToken ct) =>
{
    try
    {
        await repo.DeleteAsync(id, ct);
        return Results.NoContent();
    }
    catch (InvalidOperationException)
    {
        return Results.NotFound();
    }
    catch (SqlException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

// List + filters + pagination
group.MapGet("/", async (
    [FromQuery] int? productId,
    [FromQuery] byte? typeId,
    [FromQuery] DateTime? startUtc,
    [FromQuery] DateTime? endUtc,
    [FromQuery] int page,
    [FromQuery] int pageSize,
    [FromServices] ITransactionRepository repo,
    CancellationToken ct) =>
{
    page = page <= 0 ? 1 : page;
    pageSize = pageSize <= 0 || pageSize > 100 ? 20 : pageSize;

    var result = await repo.SearchAsync(productId, typeId, startUtc, endUtc, page, pageSize, ct);
    return Results.Ok(result);
});

// Get by id
group.MapGet("/{id:long}", async (long id, [FromServices] ITransactionRepository repo, CancellationToken ct) =>
{
    var trx = await repo.GetByIdAsync(id, ct);
    return trx is null ? Results.NotFound() : Results.Ok(trx);
});

app.UseCors("dev");
app.Run();
