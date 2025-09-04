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
