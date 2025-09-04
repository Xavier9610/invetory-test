#!/usr/bin/env bash
set -euo pipefail

# Ejecutar desde: /NewProjects/testProjects/inventory-app/frontend/angular18
# Proyecto Angular en: ./inventory-web

PROJ="inventory-web"
APP="${PROJ}/src/app"

# --- sanity check ---
if [[ ! -d "$PROJ" ]]; then
  echo "[!] No se encontró el proyecto Angular en: $PROJ" >&2
  exit 1
fi

# --- crear carpetas (environments va en src/app/environments) ---
mkdir -p \
  "$APP/core/models" \
  "$APP/core/services" \
  "$APP/features/products" \
  "$APP/shared/paginator" \
  "$APP/environments"

# --- environments (en src/app/environments) ---
cat > "$APP/environments/environment.ts" <<'TS'
export const environment = {
  production: true,
  apiProducts: 'http://localhost:5000',
  apiTransactions: 'http://localhost:5001'
};
TS

cat > "$APP/environments/environment.development.ts" <<'TS'
export const environment = {
  production: false,
  apiProducts: 'http://localhost:5000',
  apiTransactions: 'http://localhost:5001'
};
TS

# --- modelos ---
cat > "$APP/core/models/product.model.ts" <<'TS'
// DTOs aligned with backend API (Products)
export interface ProductReadDto {
  productId: number;
  name: string;
  price: number;
  stock: number;
  imageUrl?: string | null;
  isActive: boolean;
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
TS

# --- servicio HTTP (import corregido a src/app/environments) ---
cat > "$APP/core/services/product.service.ts" <<'TS'
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
TS

# --- paginator component ---
cat > "$APP/shared/paginator/paginator.component.ts" <<'TS'
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-paginator',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './paginator.component.html',
  styleUrls: ['./paginator.component.scss']
})
export class PaginatorComponent {
  @Input() total = 0;
  @Input() pageSize = 10;
  @Input() page = 1; // 1-based
  @Output() pageChange = new EventEmitter<number>();

  get totalPages(): number { return Math.max(1, Math.ceil(this.total / this.pageSize)); }
  prev() { if (this.page > 1) this.pageChange.emit(this.page - 1); }
  next() { if (this.page < this.totalPages) this.pageChange.emit(this.page + 1); }
}
TS

cat > "$APP/shared/paginator/paginator.component.html" <<'HTML'
<div class="paginator">
  <button (click)="prev()" [disabled]="page <= 1">Prev</button>
  <span>Page {{page}} / {{totalPages}}</span>
  <button (click)="next()" [disabled]="page >= totalPages">Next</button>
</div>
HTML

cat > "$APP/shared/paginator/paginator.component.scss" <<'SCSS'
.paginator { display: inline-flex; gap: .75rem; align-items: center; margin-top: 1rem; }
.paginator button { padding: .35rem .75rem; border: 1px solid #ccc; border-radius: 6px; background: white; cursor: pointer; }
.paginator button:disabled { opacity: .5; cursor: not-allowed; }
SCSS

# --- products list component ---
cat > "$APP/features/products/products-list.component.ts" <<'TS'
import { Component, OnInit, computed, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { ProductService } from '../../core/services/product.service';
import { ProductReadDto } from '../../core/models/product.model';
import { PaginatorComponent } from '../../shared/paginator/paginator.component';

@Component({
  standalone: true,
  selector: 'app-products-list',
  imports: [CommonModule, RouterLink, FormsModule, PaginatorComponent],
  templateUrl: './products-list.component.html',
  styleUrls: ['./products-list.component.scss']
})
export class ProductsListComponent implements OnInit {
  loading = signal(false);
  error = signal<string | null>(null);
  success = signal<string | null>(null);
  items = signal<ProductReadDto[]>([]);

  q = signal('');
  onlyActive = signal<'all' | 'active' | 'inactive'>('all');
  page = signal(1);
  pageSize = signal(10);

  filtered = computed(() => {
    const text = this.q().trim().toLowerCase();
    const mode = this.onlyActive();
    return this.items().filter(p => {
      const matchesText = !text || p.name.toLowerCase().includes(text);
      const matchesActive = mode === 'all' || (mode === 'active' ? p.isActive : !p.isActive);
      return matchesText && matchesActive;
    });
  });

  paged = computed(() => {
    const start = (this.page() - 1) * this.pageSize();
    return this.filtered().slice(start, start + this.pageSize());
  });

  constructor(private readonly svc: ProductService, private readonly router: Router) {}

  ngOnInit(): void { this.load(); }

  load() {
    this.loading.set(true); this.error.set(null);
    this.svc.list().subscribe({
      next: data => { this.items.set(data); this.loading.set(false); },
      error: err => { this.error.set(err?.error?.error ?? 'Failed to load products'); this.loading.set(false); }
    });
  }

  changePage(p: number) { this.page.set(p); }

  confirmDelete(id: number) {
    if (!confirm('Delete this product? This will fail if product has transactions.')) return;
    this.svc.delete(id).subscribe({
      next: () => { this.success.set('Product deleted'); this.load(); },
      error: err => this.error.set(err?.error?.error ?? 'Delete failed')
    });
  }
}
TS

cat > "$APP/features/products/products-list.component.html" <<'HTML'
<div class="page">
  <header class="header">
    <h1>Products</h1>
    <a routerLink="/products/new" class="btn">+ New</a>
  </header>

  <section class="filters">
    <input type="text" placeholder="Search by name..." [(ngModel)]="q()" (ngModelChange)="page.set(1)" />

    <select [(ngModel)]="onlyActive()" (ngModelChange)="page.set(1)">
      <option value="all">All</option>
      <option value="active">Active</option>
      <option value="inactive">Inactive</option>
    </select>
  </section>

  <div class="alerts" *ngIf="error() || success()">
    <div class="alert error" *ngIf="error()">{{error()}}</div>
    <div class="alert success" *ngIf="success()">{{success()}}</div>
  </div>

  <div *ngIf="loading()">Loading...</div>

  <table class="table" *ngIf="!loading()">
    <thead>
      <tr>
        <th>ID</th>
        <th>Name</th>
        <th>Price</th>
        <th>Stock</th>
        <th>Active</th>
        <th style="width:180px;">Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr *ngFor="let p of paged()">
        <td>{{p.productId}}</td>
        <td>{{p.name}}</td>
        <td>{{p.price | number:'1.2-2'}}</td>
        <td>{{p.stock}}</td>
        <td><span class="dot" [class.ok]="p.isActive" [title]="p.isActive ? 'Active' : 'Inactive'"></span></td>
        <td class="actions">
          <a class="btn" [routerLink]="['/products', p.productId, 'edit']">Edit</a>
          <button class="btn danger" (click)="confirmDelete(p.productId)">Delete</button>
        </td>
      </tr>
    </tbody>
  </table>

  <app-paginator
    [total]="filtered().length"
    [page]="page()"
    [pageSize]="pageSize()"
    (pageChange)="changePage($event)">
  </app-paginator>
</div>
HTML

cat > "$APP/features/products/products-list.component.scss" <<'SCSS'
.page { padding: 1rem; }
.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }
.filters { display: flex; gap: .75rem; margin-bottom: 1rem; }
.alerts { margin-bottom: .75rem; }
.alert { padding: .5rem .75rem; border-radius: 6px; }
.alert.error { background: #fde2e1; color: #7a1d18; }
.alert.success { background: #e6f7e9; color: #1c6d2a; }
.table { width: 100%; border-collapse: collapse; }
.table th, .table td { border-bottom: 1px solid #eee; padding: .5rem .35rem; text-align: left; }
.btn { display: inline-block; padding: .35rem .65rem; border-radius: 6px; border: 1px solid #ccc; background: #fff; text-decoration: none; cursor: pointer; }
.btn.danger { border-color: #e26b6b; color: #b22; }
.actions { display: flex; gap: .5rem; }
.dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; background: #aaa; }
.dot.ok { background: #2ecc71; }
SCSS

# --- product form component ---
cat > "$APP/features/products/product-form.component.ts" <<'TS'
import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { ProductService } from '../../core/services/product.service';
import { ProductCreateDto, ProductUpdateDto } from '../../core/models/product.model';

@Component({
  standalone: true,
  selector: 'app-product-form',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './product-form.component.html',
  styleUrls: ['./product-form.component.scss']
})
export class ProductFormComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly svc = inject(ProductService);

  form!: FormGroup;
  isEdit = false;
  id: number | null = null;

  loading = signal(false);
  error = signal<string | null>(null);
  success = signal<string | null>(null);

  ngOnInit(): void {
    this.form = this.fb.group({
      name: ['', [Validators.required, Validators.maxLength(200)]],
      description: [''],
      imageUrl: [''],
      price: [0, [Validators.required, Validators.min(0)]],
      isActive: [true],
      initialStock: [0, [Validators.min(0)]]
    });

    const idParam = this.route.snapshot.paramMap.get('id');
    this.isEdit = !!idParam;

    if (this.isEdit) {
      this.id = Number(idParam);
      this.form.get('initialStock')?.disable();
      this.load();
    }
  }

  load() {
    if (!this.id) return;
    this.loading.set(true);
    this.svc.get(this.id).subscribe({
      next: p => {
        this.form.patchValue({
          name: p.name,
          description: '',
          imageUrl: p.imageUrl ?? '',
          price: p.price,
          isActive: p.isActive
        });
        this.loading.set(false);
      },
      error: err => { this.error.set(err?.error?.error ?? 'Load failed'); this.loading.set(false); }
    });
  }

  submit() {
    if (this.form.invalid) { this.form.markAllAsTouched(); return; }

    this.loading.set(true); this.error.set(null); this.success.set(null);

    if (this.isEdit && this.id) {
      const body: ProductUpdateDto = {
        name: this.form.value.name,
        description: this.form.value.description || null,
        imageUrl: this.form.value.imageUrl || null,
        price: this.form.value.price,
        isActive: this.form.value.isActive
      };
      this.svc.update(this.id, body).subscribe({
        next: () => { this.success.set('Product updated'); this.loading.set(false); this.router.navigate(['/products']); },
        error: err => { this.error.set(err?.error?.error ?? 'Update failed'); this.loading.set(false); }
      });
    } else {
      const body: ProductCreateDto = {
        name: this.form.value.name,
        description: this.form.value.description || null,
        imageUrl: this.form.value.imageUrl || null,
        price: this.form.value.price,
        initialStock: this.form.value.initialStock ?? 0
      };
      this.svc.create(body).subscribe({
        next: () => { this.success.set('Product created'); this.loading.set(false); this.router.navigate(['/products']); },
        error: err => { this.error.set(err?.error?.error ?? 'Create failed'); this.loading.set(false); }
      });
    }
  }
}
TS

cat > "$APP/features/products/product-form.component.html" <<'HTML'
<div class="page">
  <header class="header">
    <h1>{{ isEdit ? 'Edit Product' : 'New Product' }}</h1>
    <a routerLink="/products" class="btn">← Back</a>
  </header>

  <div class="alerts" *ngIf="error() || success()">
    <div class="alert error" *ngIf="error()">{{error()}}</div>
    <div class="alert success" *ngIf="success()">{{success()}}</div>
  </div>

  <form [formGroup]="form" (ngSubmit)="submit()" novalidate>
    <div class="grid">
      <label>
        <span>Name *</span>
        <input type="text" formControlName="name" maxlength="200" />
      </label>

      <label>
        <span>Price *</span>
        <input type="number" formControlName="price" step="0.01" min="0" />
      </label>

      <label>
        <span>Initial Stock</span>
        <input type="number" formControlName="initialStock" min="0" />
      </label>

      <label class="full">
        <span>Description</span>
        <textarea formControlName="description" rows="3"></textarea>
      </label>

      <label class="full">
        <span>Image URL</span>
        <input type="url" formControlName="imageUrl" />
      </label>

      <label *ngIf="isEdit">
        <span>Active</span>
        <input type="checkbox" formControlName="isActive" />
      </label>
    </div>

    <div class="actions">
      <button class="btn" type="submit">{{ isEdit ? 'Save' : 'Create' }}</button>
    </div>
  </form>
</div>
HTML

cat > "$APP/features/products/product-form.component.scss" <<'SCSS'
.page { padding: 1rem; }
.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }
.grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; }
.grid label.full { grid-column: 1 / -1; }
label span { display: block; margin-bottom: .25rem; color: #444; }
input, textarea { width: 100%; padding: .5rem .6rem; border: 1px solid #ddd; border-radius: 6px; }
.actions { margin-top: 1rem; }
.btn { display: inline-block; padding: .4rem .8rem; border: 1px solid #ccc; border-radius: 6px; background: #fff; cursor: pointer; }
.alerts { margin-bottom: .75rem; }
.alert { padding: .5rem .75rem; border-radius: 6px; }
.alert.error { background: #fde2e1; color: #7a1d18; }
.alert.success { background: #e6f7e9; color: #1c6d2a; }
SCSS

# --- routes ---
if [[ -f "$APP/app.routes.ts" ]]; then mv "$APP/app.routes.ts" "$APP/app.routes.ts.bak"; fi
cat > "$APP/app.routes.ts" <<'TS'
import { Routes } from '@angular/router';
import { ProductsListComponent } from './features/products/products-list.component';
import { ProductFormComponent } from './features/products/product-form.component';

export const routes: Routes = [
  { path: '', redirectTo: 'products', pathMatch: 'full' },
  { path: 'products', component: ProductsListComponent, title: 'Products' },
  { path: 'products/new', component: ProductFormComponent, title: 'New Product' },
  { path: 'products/:id/edit', component: ProductFormComponent, title: 'Edit Product' },
  { path: '**', redirectTo: 'products' }
];
TS

# --- ensure provideHttpClient in app.config.ts ---
APP_CONFIG="$APP/app.config.ts"
if [[ -f "$APP_CONFIG" ]] && ! grep -q 'provideHttpClient' "$APP_CONFIG"; then
  sed -i "1s|^|import { provideHttpClient } from '@angular/common/http';\n|" "$APP_CONFIG"
  sed -i "s/providers: \[/providers: [\n    provideHttpClient(),/" "$APP_CONFIG"
fi

# --- advise angular.json fileReplacements for src/app/environments ---
echo
echo "[INFO] Recuerda actualizar angular.json -> build.configurations.development.fileReplacements:"
cat <<'JSON'
"fileReplacements": [
  {
    "replace": "src/app/environments/environment.ts",
    "with": "src/app/environments/environment.development.ts"
  }
]
JSON

cat <<'DONE'

[OK] Products views scaffolding complete.
Siguientes pasos:
  1) cd inventory-web
  2) npm install
  3) npm start   # http://localhost:4200

DONE

