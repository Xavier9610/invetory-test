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
  @Input() pageSize = 3;
  @Input() page = 1; // 1-based
  @Output() pageChange = new EventEmitter<number>();

  get totalPages(): number { return Math.max(1, Math.ceil(this.total / this.pageSize)); }
  prev() { if (this.page > 1) this.pageChange.emit(this.page - 1); }
  next() { if (this.page < this.totalPages) this.pageChange.emit(this.page + 1); }
}
