// DTOs aligned with backend API (Products)
export interface ProductReadDto {
  productId: number;
  name: string;
  price: number;
  stock: number;
  imageUrl?: string | null;
  isActive: boolean;
  description?: string | null; // <- añadir (opcional)
}

export interface ProductCreateDto {
  name: string;
  description?: string | null;
  imageUrl?: string | null;
  price: number;
  initialStock: number;
}

export interface ProductUpdateDto {
  name: string;
  description?: string | null;
  imageUrl?: string | null;
  price: number;
  isActive: boolean;
}
