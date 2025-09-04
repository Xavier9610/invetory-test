import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { ProductCreateDto, ProductReadDto, ProductUpdateDto } from '../models/product.model';

@Injectable({ providedIn: 'root' })
export class ProductService {
  private readonly http = inject(HttpClient);
  private readonly base = `${environment.apiProducts}/api/products`;

  list(): Observable<ProductReadDto[]> { return this.http.get<ProductReadDto[]>(this.base); }
  get(id: number): Observable<ProductReadDto> { return this.http.get<ProductReadDto>(`${this.base}/${id}`); }
  create(body: ProductCreateDto): Observable<ProductReadDto> { return this.http.post<ProductReadDto>(this.base, body); }
  update(id: number, body: ProductUpdateDto): Observable<ProductReadDto> { return this.http.put<ProductReadDto>(`${this.base}/${id}`, body); }
  delete(id: number): Observable<void> { return this.http.delete<void>(`${this.base}/${id}`); }
}
