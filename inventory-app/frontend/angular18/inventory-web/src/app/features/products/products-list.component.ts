import { Component, OnInit, computed, signal, TrackByFunction } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { ProductService } from '../../core/services/product.service';
import { ProductReadDto } from '../../core/models/product.model';
import { PaginatorComponent } from '../../shared/paginator/paginator.component';

type ActiveFilter = 'all' | 'active' | 'inactive';

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

  q = signal<string>('');                         // texto de búsqueda
  onlyActive = signal<ActiveFilter>('all');       // filtro de estado
  page = signal(1);
  pageSize = signal(3);

  // Filtrado robusto (tolera isActive undefined y name null)
  filtered = computed(() => {
    const text = (this.q() ?? '').trim().toLowerCase();
    const mode = this.onlyActive();

    return this.items().filter(p => {
      const name = (p.name ?? '').toLowerCase();
      const isActive = !!p.isActive; // fallback a false si viene undefined

      const matchesText = !text || name.includes(text);
      const matchesActive =
        mode === 'all' ||
        (mode === 'active' ? isActive : !isActive);

      return matchesText && matchesActive;
    });
  });

  paged = computed(() => {
    const start = (this.page() - 1) * this.pageSize();
    return this.filtered().slice(start, start + this.pageSize());
  });

  // Evita repintados innecesarios
  trackById: TrackByFunction<ProductReadDto> = (_i, p) => p.productId;

  constructor(private readonly svc: ProductService, private readonly router: Router) {}

  ngOnInit(): void { this.load(); }

  load() {
    this.loading.set(true); this.error.set(null);
    this.svc.list().subscribe({
      next: data => {
        // Normaliza isActive si no viene del backend
        const normalized = data.map(p => ({ ...p, isActive: !!(p as any).isActive }));
        this.items.set(normalized);
        this.page.set(1); // al cargar, ir a pág 1
        this.loading.set(false);
      },
      error: err => {
        this.error.set(err?.error?.error ?? 'Failed to load products');
        this.loading.set(false);
      }
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

  // Handlers para inputs (reset paginación)
  onSearchChange(val: string) { this.q.set(val ?? ''); this.page.set(1); }
  onActiveChange(val: string) {
    const v = (val || 'all') as ActiveFilter;
    this.onlyActive.set(v);
    this.page.set(1);
  }
}
