import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { ProductService } from '../../core/services/product.service';
import { ProductCreateDto, ProductReadDto, ProductUpdateDto } from '../../core/models/product.model';

import { TransactionService } from '../../core/services/transaction.service';
import { TransactionReadDto } from '../../core/models/transaction.model';

import { PaginatorComponent } from '../../shared/paginator/paginator.component';

@Component({
  standalone: true,
  selector: 'app-product-form',
  imports: [CommonModule, ReactiveFormsModule, RouterLink, PaginatorComponent],
  templateUrl: './product-form.component.html',
  styleUrls: ['./product-form.component.scss']
})
export class ProductFormComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly products = inject(ProductService);
  private readonly tx = inject(TransactionService);

  form!: FormGroup;
  isEdit = false;
  id: number | null = null;

  loading = signal(false);
  error = signal<string | null>(null);
  success = signal<string | null>(null);

  product: ProductReadDto | null = null;

  // Historial
  trxLoading = signal(false);
  trxError = signal<string | null>(null);
  trxItems = signal<TransactionReadDto[]>([]);
  trxTotal = signal(0);
  trxPage = signal(1);
  trxPageSize = signal(10);

  // Filtros por fecha del historial
  trxFilters!: FormGroup; // { start: 'yyyy-MM-dd' | '', end: 'yyyy-MM-dd' | '' }

  // Form inline de transacción (Purchase/Sell)
  showTrxForm = signal(false);
  trxTypeId = signal<1 | 2>(1); // 1=Purchase, 2=Sale
  trxForm!: FormGroup;

  ngOnInit(): void {
    // Form de producto
    this.form = this.fb.group({
      name: ['', [Validators.required, Validators.maxLength(200)]],
      description: [''],
      imageUrl: [''],
      price: [0, [Validators.required, Validators.min(0)]],
      isActive: [true],
      initialStock: [0, [Validators.min(0)]]
    });

    // Form de transacción
    this.trxForm = this.fb.group({
      quantity: [1, [Validators.required, Validators.min(1)]],
      unitPrice: [0, [Validators.required, Validators.min(0)]],
      detail: ['']
    });

    // Form de filtros (fechas)
    this.trxFilters = this.fb.group({
      start: [''],
      end: ['']
    });

    const idParam = this.route.snapshot.paramMap.get('id');
    this.isEdit = !!idParam;

    if (this.isEdit) {
      this.id = Number(idParam);
      this.form.get('initialStock')?.disable();
      this.loadProduct();
      this.loadTransactions();
    }
  }

  // ---------- Producto ----------
  loadProduct() {
    if (!this.id) return;
    this.loading.set(true); this.error.set(null);
    this.products.get(this.id).subscribe({
      next: p => {
        this.product = p;
        this.form.patchValue({
          name: p.name,
          description: p.description ?? '',
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
      this.products.update(this.id, body).subscribe({
        next: () => { this.success.set('Product updated'); this.loading.set(false); this.loadProduct(); },
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
      this.products.create(body).subscribe({
        next: created => { this.success.set('Product created'); this.loading.set(false); this.router.navigate(['/products', created.productId, 'edit']); },
        error: err => { this.error.set(err?.error?.error ?? 'Create failed'); this.loading.set(false); }
      });
    }
  }

  // ---------- Historial ----------
  loadTransactions(page = this.trxPage(), pageSize = this.trxPageSize()) {
    if (!this.id) return;
    this.trxLoading.set(true); this.trxError.set(null);

    const { start, end } = this.trxFilters.value as { start?: string; end?: string };
    const startUtc = start ? this.toUtcStart(start) : undefined;
    const endUtc   = end   ? this.toUtcEnd(end)   : undefined;

    this.tx.search({ productId: this.id, page, pageSize, startUtc, endUtc }).subscribe({
      next: res => {
        this.trxItems.set(res.items);
        this.trxTotal.set(res.total);
        this.trxPage.set(res.page);
        this.trxPageSize.set(res.pageSize);
        this.trxLoading.set(false);
      },
      error: err => { this.trxError.set(err?.error?.error ?? 'Failed to load transactions'); this.trxLoading.set(false); }
    });
  }

  applyTrxFilters() {
    const { start, end } = this.trxFilters.value as { start?: string; end?: string };
    if (start && end && new Date(start) > new Date(end)) {
      this.trxError.set('La fecha "Hasta" debe ser posterior a "Desde".');
      return;
    }
    this.trxError.set(null);
    this.trxPage.set(1);
    this.loadTransactions(1, this.trxPageSize());
  }

  clearTrxFilters() {
    this.trxFilters.reset({ start: '', end: '' });
    this.applyTrxFilters();
  }

  changeTrxPage(p: number) { this.loadTransactions(p, this.trxPageSize()); }

  // ---------- Purchase / Sell ----------
  openTrxForm(type: 1 | 2) {
    this.trxTypeId.set(type);
    this.trxForm.reset({ quantity: 1, unitPrice: this.form.value.price ?? 0, detail: '' });
    this.showTrxForm.set(true);
  }

  cancelTrx() { this.showTrxForm.set(false); }

  submitTrx() {
    if (!this.id || this.trxForm.invalid) { this.trxForm.markAllAsTouched(); return; }

    const body = {
      transactionTypeId: this.trxTypeId(),
      productId: this.id,
      quantity: this.trxForm.value.quantity,
      unitPrice: this.trxForm.value.unitPrice,
      detail: this.trxForm.value.detail || null
    };

    this.trxLoading.set(true); this.trxError.set(null);

    this.tx.create(body).subscribe({
      next: _ => {
        this.showTrxForm.set(false);
        this.trxLoading.set(false);
        this.loadTransactions(1, this.trxPageSize()); // recarga historial
        this.loadProduct();                            // refresca stock
        this.success.set(this.trxTypeId() === 1 ? 'Purchase created' : 'Sale created');
      },
      error: err => {
        this.trxError.set(err?.error?.error ?? 'Transaction failed');
        this.trxLoading.set(false);
      }
    });
  }

  // Helpers: local date (yyyy-MM-dd) -> UTC ISO
  private toUtcStart(dateYmd: string): string {
    return new Date(`${dateYmd}T00:00:00`).toISOString();
  }
  private toUtcEnd(dateYmd: string): string {
    return new Date(`${dateYmd}T23:59:59.999`).toISOString();
  }
}
