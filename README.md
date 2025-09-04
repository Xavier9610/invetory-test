# Inventory App

Sistema de gestión de inventarios desarrollado con arquitectura de microservicios en **.NET 8** y **Angular 18**.

## 🚀 Requisitos previos

- .NET 8 SDK
- Node.js 18+ y npm
- Docker y Docker Compose
- Git

---

## 📦 Instalación y configuración

### 1) Clonar el repositorio
```bash
git clone https://github.com/<tu-usuario>/<tu-repo>.git
cd <tu-repo>   # p.ej. inventory-app
```

### 2) Levantar base de datos con Docker
```bash
docker compose up -d sqlserver db-init

```
### 3) Limpiar y compilar la solución (backend)
```bash
dotnet clean
dotnet build

```

## Ejecución de la aplicación (backend)

## Backend – Microservicios

### Products Service (puerto 5000)
```bash
dotnet run --project backend/netcore8/products/Products.Api --urls http://localhost:5000


```
### Transaction Service (puerto 5017)
```bash
dotnet run --project backend/netcore8/transactions/Transactions.Api --urls http://localhost:5017


```
## Ejecución de frontend

### Products Service (puerto 5000)
```bash
cd frontend/angular18/inventory-web/
npm install
npm start



```
## Evidencias 

### • Listado dinámico de productos y transacciones con paginación.
<img width="1072" height="531" alt="image" src="https://github.com/user-attachments/assets/50c1bfac-ad81-417c-ab1b-cf1e7541ac19" />

### • Pantalla para la creación de productos.
<img width="1072" height="586" alt="image" src="https://github.com/user-attachments/assets/f198b416-81aa-4dd1-999c-ba4ac6fac049" />

### • Pantalla para la edición de productos.
<img width="1072" height="586" alt="image" src="https://github.com/user-attachments/assets/b42d81b6-8823-4dae-aa94-401e0105e475" />

### • Pantalla para la creación de transacciones.
<img width="1024" height="234" alt="image" src="https://github.com/user-attachments/assets/c4916025-397f-442a-95ae-7bd7da04567d" />

### • Pantalla para la edición de transacciones.
<img width="1024" height="234" alt="image" src="https://github.com/user-attachments/assets/f74362a1-ca03-4237-a8f0-499c7379dbbc" />

### • Pantalla de filtros dinámicos.
<img width="1051" height="355" alt="image" src="https://github.com/user-attachments/assets/60f0008a-923c-499d-96e2-7c5b41604e6d" />

<img width="1013" height="311" alt="image" src="https://github.com/user-attachments/assets/33173918-8a7f-413a-b1a1-d9fcf8f3d30e" />

