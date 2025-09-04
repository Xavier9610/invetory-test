using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Products.Application.Dtos;
using Products.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

// Services
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
builder.Services.AddScoped<IProductRepository, ProductRepository>();

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
app.MapGet("/", () => Results.Ok("Products.Api up"));

// Group routes
var group = app.MapGroup("/api/products");


// Usa CORS antes de mapear endpoints
app.UseCors("dev");


// List
group.MapGet("/", async ([FromServices] IProductRepository repo, CancellationToken ct) =>
{
    var items = await repo.ListAsync(ct);
    return Results.Ok(items);
});

// Get by id
group.MapGet("/{id:int}", async (int id, [FromServices] IProductRepository repo, CancellationToken ct) =>
{
    var item = await repo.GetByIdAsync(id, ct);
    return item is null ? Results.NotFound() : Results.Ok(item);
});

// Create
group.MapPost("/", async ([FromBody] ProductCreateDto dto, [FromServices] IProductRepository repo, CancellationToken ct) =>
{
    try
    {
        var id = await repo.AddAsync(dto, ct);
        var created = await repo.GetByIdAsync(id, ct);
        return Results.Created($"/api/products/{id}", created);
    }
    catch (SqlException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

// Update
group.MapPut("/{id:int}", async (int id, [FromBody] ProductUpdateDto dto, [FromServices] IProductRepository repo, CancellationToken ct) =>
{
    try
    {
        await repo.UpdateAsync(id, dto, ct);
        var updated = await repo.GetByIdAsync(id, ct);
        return updated is null ? Results.NotFound() : Results.Ok(updated);
    }
    catch (SqlException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

// Delete
group.MapDelete("/{id:int}", async (int id, [FromServices] IProductRepository repo, CancellationToken ct) =>
{
    try
    {
        await repo.DeleteAsync(id, ct);
        return Results.NoContent();
    }
    catch (SqlException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});
app.Run();
