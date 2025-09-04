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

# 1 Backend – Microservicios

# Products Service (puerto 5000)
```bash
dotnet run --project backend/netcore8/products/Products.Api --urls http://localhost:5000


```
# Transaction Service (puerto 5000)
```bash
dotnet run --project backend/netcore8/transactions/Transactions.Api --urls http://localhost:5017


```
## Ejecución de frontend

# 1 Backend – Microservicios

# Products Service (puerto 5000)
```bash
cd frontend/angular18/inventory-web/
npm install
npm start



```
## Evidencias 

## • Listado dinámico de productos y transacciones con paginación.
<img width="1072" height="531" alt="image" src="https://github.com/user-attachments/assets/50c1bfac-ad81-417c-ab1b-cf1e7541ac19" />

## • Pantalla para la creación de productos.

## • Pantalla para la edición de productos.

## • Pantalla para la creación de transacciones.

## • Pantalla para la edición de transacciones.

## • Pantalla de filtros dinámicos.

## • Pantalla para la consulta de información de un formulario (extra).
