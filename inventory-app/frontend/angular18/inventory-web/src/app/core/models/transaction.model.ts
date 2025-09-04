export interface TransactionReadDto {
  inventoryTransactionId: number;
  occurredAt: string; // ISO
  transactionTypeId: number; // 1=Purchase, 2=Sale
  transactionType: string;
  productId: number;
  productName: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
  detail?: string | null;
}

export interface TransactionCreateDto {
  transactionTypeId: number; // 1 or 2
  productId: number;
  quantity: number;
  unitPrice: number;
  detail?: string | null;
  occurredAt?: string; // optional ISO
}

export interface PagedResult<T> {
  items: T[];
  total: number;
  page: number;      // 1-based
  pageSize: number;
}
