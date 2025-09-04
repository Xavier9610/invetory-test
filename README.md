#Inventory App

Sistema de gestión de inventarios desarrollado con arquitectura de microservicios en .NET y Angular.
#🚀 Requisitos Previos

    -.NET 8 SDK

    -Node.js 18+ y npm

    -Docker y Docker Compose

    -Git

#📦 Instalación y Configuración
1. Clonar el Repositorio
bash

git clone <url-del-repositorio>
cd inventory-app

2. Levantar Base de Datos con Docker
bash

docker compose up -d sqlserver db-init

3. Compilar la Solución Backend
bash

dotnet clean
dotnet build

#🏃‍♂️ Ejecución de la Aplicación
Backend - Microservicios

Products Service (puerto 5000):
bash

dotnet run --project backend/netcore8/products/Products.Api --urls http://localhost:5000

Transactions Service (puerto 5017):
bash

dotnet run --project backend/netcore8/transactions/Transactions.Api --urls http://localhost:5017

Frontend - Angular
bash

cd frontend/angular18/inventory-web/
npm install
npm start

El frontend estará disponible en: http://localhost:4200
