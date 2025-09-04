namespace Transactions.Application.Dtos
{

    // Input DTO for creating a transaction
    public  class TransactionCreateDto
    {
        public byte TransactionTypeId { get; set; }   // 1=Purchase, 2=Sale
        public int ProductId { get; set; }
        public int Quantity { get; set; }             // > 0
        public decimal UnitPrice { get; set; }        // >= 0
        public string? Detail { get; set; }
        public DateTime? OccurredAt { get; set; }     // optional (UTC)
    }

    // Input DTO for updating a transaction
    public  class TransactionUpdateDto
    {
        public byte TransactionTypeId { get; set; }
        public int ProductId { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public string? Detail { get; set; }
        public DateTime? OccurredAt { get; set; }
    }

    // Output DTO for listing/reading
    public  class TransactionReadDto
    {
        public long InventoryTransactionId { get; set; }
        public DateTime OccurredAt { get; set; }
        public byte TransactionTypeId { get; set; }
        public string TransactionType { get; set; } = default!;
        public int ProductId { get; set; }
        public string ProductName { get; set; } = default!;
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
        public string? Detail { get; set; }
    }

    // Paged result envelope
    public class PagedResult<T>
    {
        public IReadOnlyList<T> Items { get; set; } = Array.Empty<T>();
        public int Total { get; set; }
        public int Page { get; set; }         // 1-based
        public int PageSize { get; set; }
    }
}