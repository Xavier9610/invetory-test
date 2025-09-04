import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { PagedResult, TransactionCreateDto, TransactionReadDto } from '../models/transaction.model';

@Injectable({ providedIn: 'root' })
export class TransactionService {
  private readonly http = inject(HttpClient);
  private readonly base = `${environment.apiTransactions}/api/transactions`;

  // Search by optional filters; for history we’ll pass productId, page and pageSize.
  search(opts: {
    productId?: number;
    typeId?: number;
    startUtc?: string;
    endUtc?: string;
    page?: number;
    pageSize?: number;
  }): Observable<PagedResult<TransactionReadDto>> {
    let params = new HttpParams();
    if (opts.productId != null) params = params.set('productId', String(opts.productId));
    if (opts.typeId != null)    params = params.set('typeId', String(opts.typeId));
    if (opts.startUtc)          params = params.set('startUtc', opts.startUtc);
    if (opts.endUtc)            params = params.set('endUtc', opts.endUtc);
    params = params.set('page', String(opts.page ?? 1));
    params = params.set('pageSize', String(opts.pageSize ?? 10));
    return this.http.get<PagedResult<TransactionReadDto>>(this.base, { params });
  }

  create(body: TransactionCreateDto): Observable<TransactionReadDto> {
    return this.http.post<TransactionReadDto>(this.base, body);
  }
}
