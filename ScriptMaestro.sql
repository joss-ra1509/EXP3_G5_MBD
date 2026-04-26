/* =========================================================
   EXPERIENCIA 3: MODELAMIENTO Y PROGRAMACIÓN DE BD
   GRUPO 5 - VERSIÓN FINAL CORREGIDA 
   ========================================================= 
*/

USE master;
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SistemaVentas_G5')
BEGIN
    ALTER DATABASE SistemaVentas_G5 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SistemaVentas_G5;
END
GO
CREATE DATABASE SistemaVentas_G5;
GO
USE SistemaVentas_G5;
GO

-- =========================================================
-- 1. ESTRUCTURA DE TABLAS (INTERRELACIONADAS)
-- =========================================================

CREATE TABLE Clientes (
    DUI               VARCHAR(10)  PRIMARY KEY,
    Nombre_Completo   VARCHAR(150) NOT NULL,
    Email             VARCHAR(100),
    ID_Estado         INT          DEFAULT 1  -- 1: Activo, 0: Inactivo
);

CREATE TABLE Productos (
    ID_Producto       INT          IDENTITY(1,1) PRIMARY KEY,
    Nombre_Producto   VARCHAR(100) NOT NULL,
    Precio_Costo      DECIMAL(10,2) NOT NULL,
    Margen_Ganancia   DECIMAL(5,2)  NOT NULL,
    Precio_Venta      DECIMAL(10,2) NOT NULL,
    Stock_Actual      INT           NOT NULL DEFAULT 0,
    ID_Estado         INT           DEFAULT 1  -- 1: Activo, 0: Inactivo
);

CREATE TABLE Pedidos (
    ID_Pedido         INT          IDENTITY(1,1) PRIMARY KEY,
    DUI_Cliente       VARCHAR(10)  NOT NULL,
    Fecha_Pedido      DATETIME     DEFAULT GETDATE(),
    Total_Venta       DECIMAL(10,2) DEFAULT 0,
    ID_Estado         INT          DEFAULT 1,
    FOREIGN KEY (DUI_Cliente) REFERENCES Clientes(DUI)
);

CREATE TABLE Detalle_Pedido (
    ID_Detalle                INT          IDENTITY(1,1) PRIMARY KEY,
    ID_Pedido                 INT          NOT NULL,
    ID_Producto               INT          NOT NULL,
    Cantidad                  INT          NOT NULL,
    Precio_Unitario_Historico DECIMAL(10,2) NOT NULL,
    Subtotal                  DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (ID_Pedido)   REFERENCES Pedidos(ID_Pedido),
    FOREIGN KEY (ID_Producto) REFERENCES Productos(ID_Producto)
);
GO


-- =========================================================
-- 2. FUNCIONES DE VALIDACIÓN (REGLAS DE NEGOCIO)
-- =========================================================

-- Verifica si un cliente existe por DUI
CREATE FUNCTION fn_ClienteExiste(@dui VARCHAR(10)) RETURNS INT AS
BEGIN
    RETURN (SELECT COUNT(*) FROM Clientes WHERE DUI = @dui)
END
GO

-- Verifica si un producto existe por ID
CREATE FUNCTION fn_ProductoExiste(@id INT) RETURNS INT AS
BEGIN
    RETURN (SELECT COUNT(*) FROM Productos WHERE ID_Producto = @id)
END
GO

-- Verifica si hay stock suficiente para una venta
CREATE FUNCTION fn_ValidaStock(@id INT, @cant INT) RETURNS INT AS
BEGIN
    DECLARE @s INT = (SELECT Stock_Actual FROM Productos WHERE ID_Producto = @id)
    RETURN CASE WHEN @s >= @cant THEN 1 ELSE 0 END
END
GO

-- Valida formato de email (debe tener @ y dominio)
CREATE FUNCTION fn_ValidarEmail(@email VARCHAR(100)) RETURNS INT AS
BEGIN
    RETURN CASE WHEN @email LIKE '%_@__%.__%' THEN 1 ELSE 0 END
END
GO

-- Calcula el subtotal de una línea de venta
CREATE FUNCTION fn_CalculaSubtotal(@idProd INT, @cant INT) RETURNS DECIMAL(10,2) AS
BEGIN
    RETURN (SELECT Precio_Venta * @cant FROM Productos WHERE ID_Producto = @idProd)
END
GO

-- Valida que el DUI tenga exactamente 10 caracteres (ej: 12345678-9)
CREATE FUNCTION fn_ValidarDUI(@dui VARCHAR(10)) RETURNS INT AS
BEGIN
    RETURN CASE WHEN LEN(@dui) = 10 THEN 1 ELSE 0 END
END
GO

-- FIX: usa ISNULL para retornar 0 si el producto no existe, evitando NULL
CREATE FUNCTION fn_ProductoActivo(@id INT) RETURNS INT AS
BEGIN
    RETURN ISNULL((SELECT ID_Estado FROM Productos WHERE ID_Producto = @id), 0)
END
GO

-- Valida que el precio de costo sea mayor a cero
CREATE FUNCTION fn_ValidarPrecioCosto(@costo DECIMAL(10,2)) RETURNS INT AS
BEGIN
    RETURN CASE WHEN @costo > 0 THEN 1 ELSE 0 END
END
GO

-- Valida que el stock inicial no sea negativo
CREATE FUNCTION fn_ValidarStockInicial(@stock INT) RETURNS INT AS
BEGIN
    RETURN CASE WHEN @stock >= 0 THEN 1 ELSE 0 END
END
GO

-- Verifica si un cliente está activo (no dado de baja)
CREATE FUNCTION fn_ClienteActivo(@dui VARCHAR(10)) RETURNS INT AS
BEGIN
    RETURN ISNULL((SELECT ID_Estado FROM Clientes WHERE DUI = @dui), 0)
END
GO


-- =========================================================
-- 3. PROCEDIMIENTOS ALMACENADOS (CRUD COMPLETO + OPERACIONES)
-- =========================================================

-- ---------------------------------------------------------
-- CRUD CLIENTES
-- ---------------------------------------------------------

CREATE PROCEDURE sp_InsertarCliente
    @dui    VARCHAR(10),
    @nombre VARCHAR(150),
    @email  VARCHAR(100)
AS
BEGIN
    IF dbo.fn_ValidarDUI(@dui)       = 0 THROW 50001, 'DUI debe tener exactamente 10 caracteres (formato: 00000000-0)', 1
    IF dbo.fn_ValidarEmail(@email)   = 0 THROW 50002, 'El Email no tiene un formato válido', 1
    IF dbo.fn_ClienteExiste(@dui)    > 0 THROW 50003, 'El Cliente ya existe en el sistema', 1
    INSERT INTO Clientes VALUES (@dui, @nombre, @email, 1)
END
GO

CREATE PROCEDURE sp_UpdateCliente
    @dui    VARCHAR(10),
    @nombre VARCHAR(150),
    @email  VARCHAR(100)
AS
BEGIN
    IF dbo.fn_ClienteExiste(@dui)  = 0 THROW 50004, 'Cliente no existe, no se puede actualizar', 1
    IF dbo.fn_ValidarEmail(@email) = 0 THROW 50002, 'El Email no tiene un formato válido', 1
    UPDATE Clientes SET Nombre_Completo = @nombre, Email = @email WHERE DUI = @dui
END
GO

-- FIX: agrega validación de existencia antes de intentar borrar
CREATE PROCEDURE sp_DeleteCliente
    @dui VARCHAR(10)
AS
BEGIN
    IF dbo.fn_ClienteExiste(@dui) = 0
        THROW 50013, 'Cliente no existe, no se puede eliminar', 1
    IF EXISTS (SELECT 1 FROM Pedidos WHERE DUI_Cliente = @dui)
        THROW 50005, 'No se puede eliminar: Cliente tiene pedidos vinculados (Trazabilidad)', 1
    DELETE FROM Clientes WHERE DUI = @dui
END
GO


-- ---------------------------------------------------------
-- CRUD PRODUCTOS
-- ---------------------------------------------------------

CREATE PROCEDURE sp_InsertarProducto
    @nom    VARCHAR(100),
    @costo  DECIMAL(10,2),
    @margen DECIMAL(5,2),
    @stock  INT
AS
BEGIN
    IF dbo.fn_ValidarPrecioCosto(@costo)    = 0 THROW 50010, 'El precio de costo debe ser mayor a cero', 1
    IF @margen < 0                              THROW 50011, 'El margen de ganancia no puede ser negativo', 1
    IF dbo.fn_ValidarStockInicial(@stock)   = 0 THROW 50016, 'El stock inicial no puede ser negativo', 1
    DECLARE @venta DECIMAL(10,2) = @costo + (@costo * (@margen / 100))
    INSERT INTO Productos (Nombre_Producto, Precio_Costo, Margen_Ganancia, Precio_Venta, Stock_Actual, ID_Estado)
    VALUES (@nom, @costo, @margen, @venta, @stock, 1)
END
GO

CREATE PROCEDURE sp_ActualizarProducto
    @id     INT,
    @nom    VARCHAR(100),
    @costo  DECIMAL(10,2),
    @margen DECIMAL(5,2)
AS
BEGIN
    IF dbo.fn_ProductoExiste(@id)           = 0 THROW 50006, 'Producto no existe, no se puede actualizar', 1
    IF dbo.fn_ValidarPrecioCosto(@costo)    = 0 THROW 50010, 'El precio de costo debe ser mayor a cero', 1
    IF @margen < 0                              THROW 50011, 'El margen de ganancia no puede ser negativo', 1
    DECLARE @venta DECIMAL(10,2) = @costo + (@costo * (@margen / 100))
    UPDATE Productos
    SET Nombre_Producto = @nom,
        Precio_Costo    = @costo,
        Margen_Ganancia = @margen,
        Precio_Venta    = @venta
    WHERE ID_Producto = @id
END
GO

CREATE PROCEDURE sp_ActualizarStock
    @id         INT,
    @nuevoStock INT
AS
BEGIN
    IF dbo.fn_ProductoExiste(@id) = 0 THROW 50006, 'Producto no existe', 1
    IF @nuevoStock <= 0               THROW 50017, 'La cantidad a agregar al stock debe ser mayor a cero', 1
    UPDATE Productos SET Stock_Actual = Stock_Actual + @nuevoStock WHERE ID_Producto = @id
END
GO

-- Baja lógica (preserva trazabilidad histórica)
CREATE PROCEDURE sp_DarBajaProducto
    @id INT
AS
BEGIN
    IF dbo.fn_ProductoExiste(@id) = 0 THROW 50006, 'Producto no existe', 1
    UPDATE Productos SET ID_Estado = 0 WHERE ID_Producto = @id
END
GO

-- Eliminación física (solo si no tiene ventas registradas)
CREATE PROCEDURE sp_DeleteProducto
    @id INT
AS
BEGIN
    IF dbo.fn_ProductoExiste(@id) = 0
        THROW 50006, 'Producto no existe, no se puede eliminar', 1
    IF EXISTS (SELECT 1 FROM Detalle_Pedido WHERE ID_Producto = @id)
        THROW 50014, 'No se puede eliminar: Producto tiene ventas vinculadas (Trazabilidad)', 1
    DELETE FROM Productos WHERE ID_Producto = @id
END
GO


-- ---------------------------------------------------------
-- PROCESO DE VENTA (CON TRAZABILIDAD)
-- ---------------------------------------------------------

-- FIX: orden correcto de validaciones — existencia ANTES que estado activo
CREATE PROCEDURE sp_RegistrarVenta
    @dui    VARCHAR(10),
    @idProd INT,
    @cant   INT
AS
BEGIN
    IF @cant <= 0                                   THROW 50015, 'La cantidad de venta debe ser mayor a cero', 1
    IF dbo.fn_ClienteExiste(@dui)         = 0       THROW 50007, 'Cliente no existe', 1
    IF dbo.fn_ClienteActivo(@dui)         = 0       THROW 50018, 'El Cliente se encuentra INACTIVO', 1
    IF dbo.fn_ProductoExiste(@idProd)     = 0       THROW 50008, 'Producto no existe', 1
    IF dbo.fn_ProductoActivo(@idProd)     = 0       THROW 50009, 'Producto se encuentra INACTIVO', 1
    IF dbo.fn_ValidaStock(@idProd, @cant) = 0       THROW 50012, 'Stock insuficiente para realizar la venta', 1

    DECLARE @total DECIMAL(10,2) = dbo.fn_CalculaSubtotal(@idProd, @cant)
    DECLARE @idPed INT

    INSERT INTO Pedidos (DUI_Cliente, Total_Venta) VALUES (@dui, @total)
    SET @idPed = SCOPE_IDENTITY()

    INSERT INTO Detalle_Pedido (ID_Pedido, ID_Producto, Cantidad, Precio_Unitario_Historico, Subtotal)
    VALUES (@idPed, @idProd, @cant, (@total / @cant), @total)

    UPDATE Productos SET Stock_Actual = Stock_Actual - @cant WHERE ID_Producto = @idProd
END
GO


-- ---------------------------------------------------------
-- REPORTES
-- ---------------------------------------------------------

CREATE PROCEDURE sp_ReporteBajoStock AS
    SELECT * FROM Productos WHERE Stock_Actual < 3 AND ID_Estado = 1
GO

CREATE PROCEDURE sp_ListarClientes AS
    SELECT * FROM Clientes
GO

CREATE PROCEDURE sp_ListarProductos AS
    SELECT * FROM Productos
GO

-- Reporte de ventas agrupadas por cliente
CREATE PROCEDURE sp_ReporteVentasPorCliente AS
    SELECT
        c.DUI,
        c.Nombre_Completo,
        COUNT(p.ID_Pedido)   AS Total_Pedidos,
        SUM(p.Total_Venta)   AS Monto_Total_Vendido
    FROM Clientes c
    JOIN Pedidos  p ON c.DUI = p.DUI_Cliente
    GROUP BY c.DUI, c.Nombre_Completo
GO

-- Reporte de detalle de ventas con nombre de producto
CREATE PROCEDURE sp_ReporteDetallePedidos AS
    SELECT
        p.ID_Pedido,
        c.Nombre_Completo  AS Cliente,
        pr.Nombre_Producto AS Producto,
        dp.Cantidad,
        dp.Precio_Unitario_Historico,
        dp.Subtotal,
        p.Fecha_Pedido
    FROM Pedidos        p
    JOIN Clientes       c  ON p.DUI_Cliente  = c.DUI
    JOIN Detalle_Pedido dp ON p.ID_Pedido    = dp.ID_Pedido
    JOIN Productos      pr ON dp.ID_Producto = pr.ID_Producto
GO


-- =========================================================
-- 4. BATERÍA DE PRUEBAS (25 CASOS DE USO)
-- =========================================================

PRINT '=========================================='
PRINT ' BATERÍA DE PRUEBAS - GRUPO 5'
PRINT '=========================================='


-- ----------------------------------------------------------
-- A. CARGA INICIAL DE DATOS
-- ----------------------------------------------------------
PRINT '--- A. CARGA INICIAL ---'

EXEC sp_InsertarProducto 'Monitor 24"',   100.00, 25.00, 10  -- ID 1
EXEC sp_InsertarProducto 'Teclado RGB',    20.00, 50.00,  5  -- ID 2
EXEC sp_InsertarProducto 'Mouse Pro',      10.00, 50.00,  2  -- ID 3
EXEC sp_InsertarProducto 'Audífonos BT',   35.00, 40.00,  8  -- ID 4
EXEC sp_InsertarProducto 'Webcam HD',      45.00, 30.00,  6  -- ID 5

EXEC sp_InsertarCliente '12345678-9', 'Yoselyn Rivera',   'yoselyn@edu.sv'
EXEC sp_InsertarCliente '98765432-1', 'Raul Andrade',     'raul@edu.sv'
EXEC sp_InsertarCliente '11223344-5', 'Maria González',   'maria@edu.sv'

SELECT 'Productos iniciales cargados' AS [Info]; SELECT * FROM Productos;
SELECT 'Clientes iniciales cargados'  AS [Info]; SELECT * FROM Clientes;


-- ----------------------------------------------------------
-- B. PRUEBAS DE FUNCIONAMIENTO CORRECTO (ÉXITOS ESPERADOS)
-- ----------------------------------------------------------
PRINT '--- B. OPERACIONES CORRECTAS ---'

-- P1: Venta exitosa
EXEC sp_RegistrarVenta '12345678-9', 1, 2
SELECT 'P1 OK - Venta de Monitor registrada' AS [RESULTADO_PRUEBA]

-- P2: Agregar stock
EXEC sp_ActualizarStock 3, 10
SELECT 'P2 OK - Stock de Mouse Pro actualizado' AS [RESULTADO_PRUEBA]

-- P3: Actualizar datos de cliente
EXEC sp_UpdateCliente '98765432-1', 'Raul Alberto Andrade', 'raul.a@mail.com'
SELECT 'P3 OK - Cliente actualizado' AS [RESULTADO_PRUEBA]

-- P4: Segunda venta exitosa
EXEC sp_RegistrarVenta '98765432-1', 2, 2
SELECT 'P4 OK - Venta de Teclado registrada' AS [RESULTADO_PRUEBA]

-- P5: Actualizar datos de producto
EXEC sp_ActualizarProducto 4, 'Audífonos BT Pro', 40.00, 45.00
SELECT 'P5 OK - Producto actualizado con nuevo margen' AS [RESULTADO_PRUEBA]

-- P6: Eliminar producto sin ventas
EXEC sp_InsertarProducto 'Producto Temporal', 10.00, 10.00, 0
EXEC sp_DeleteProducto 6
SELECT 'P6 OK - Producto sin ventas eliminado físicamente' AS [RESULTADO_PRUEBA]

-- P7: Reporte de ventas por cliente
SELECT 'P7 OK - Reporte de ventas por cliente:' AS [RESULTADO_PRUEBA]
EXEC sp_ReporteVentasPorCliente

-- P8: Reporte detalle de pedidos
SELECT 'P8 OK - Reporte de detalle de pedidos:' AS [RESULTADO_PRUEBA]
EXEC sp_ReporteDetallePedidos


-- ----------------------------------------------------------
-- C. PRUEBAS DE VALIDACIÓN (ERRORES ESPERADOS)
-- ----------------------------------------------------------
PRINT '--- C. VALIDACIONES DE ERROR ---'

-- P9: DUI demasiado corto
BEGIN TRY
    EXEC sp_InsertarCliente '123', 'Error DUI corto', 'test@mail.com'
END TRY
BEGIN CATCH
    SELECT 'P9 - DUI corto: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P10: DUI demasiado largo
BEGIN TRY
    EXEC sp_InsertarCliente '12345678-900', 'Error DUI largo', 'test@mail.com'
END TRY
BEGIN CATCH
    SELECT 'P10 - DUI largo: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P11: Email sin @
BEGIN TRY
    EXEC sp_InsertarCliente '00000000-0', 'Test Email', 'email_sin_arroba'
END TRY
BEGIN CATCH
    SELECT 'P11 - Email inválido: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P12: Cliente duplicado
BEGIN TRY
    EXEC sp_InsertarCliente '12345678-9', 'Duplicado', 'test@mail.com'
END TRY
BEGIN CATCH
    SELECT 'P12 - Cliente duplicado: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P13: Venta con stock insuficiente
BEGIN TRY
    EXEC sp_RegistrarVenta '12345678-9', 1, 999
END TRY
BEGIN CATCH
    SELECT 'P13 - Stock insuficiente: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P14: Venta con producto inexistente (FIX: ahora muestra "Producto no existe", no "Inactivo")
BEGIN TRY
    EXEC sp_RegistrarVenta '12345678-9', 9999, 1
END TRY
BEGIN CATCH
    SELECT 'P14 - Producto inexistente: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P15: Venta con cliente inexistente
BEGIN TRY
    EXEC sp_RegistrarVenta '00000000-0', 1, 1
END TRY
BEGIN CATCH
    SELECT 'P15 - Cliente inexistente: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P16: Venta con producto inactivo
EXEC sp_DarBajaProducto 2
BEGIN TRY
    EXEC sp_RegistrarVenta '12345678-9', 2, 1
END TRY
BEGIN CATCH
    SELECT 'P16 - Producto inactivo: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P17: Borrar cliente con pedidos vinculados (Trazabilidad)
BEGIN TRY
    EXEC sp_DeleteCliente '12345678-9'
END TRY
BEGIN CATCH
    SELECT 'P17 - Trazabilidad cliente: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P18: Borrar cliente que no existe (FIX: ahora valida antes de intentar borrar)
BEGIN TRY
    EXEC sp_DeleteCliente '00000000-0'
END TRY
BEGIN CATCH
    SELECT 'P18 - Delete cliente inexistente: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P19: Actualizar stock de producto inexistente
BEGIN TRY
    EXEC sp_ActualizarStock 500, 10
END TRY
BEGIN CATCH
    SELECT 'P19 - Stock producto inexistente: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P20: Cantidad de venta igual a cero
BEGIN TRY
    EXEC sp_RegistrarVenta '12345678-9', 3, 0
END TRY
BEGIN CATCH
    SELECT 'P20 - Cantidad cero: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P21: Margen de ganancia negativo
BEGIN TRY
    EXEC sp_InsertarProducto 'Producto Error', 100.00, -50.00, 10
END TRY
BEGIN CATCH
    SELECT 'P21 - Margen negativo: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P22: Precio de costo igual a cero
BEGIN TRY
    EXEC sp_InsertarProducto 'Producto Error', 0.00, 20.00, 5
END TRY
BEGIN CATCH
    SELECT 'P22 - Costo cero: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P23: Actualizar cliente inexistente
BEGIN TRY
    EXEC sp_UpdateCliente '11111111-1', 'No Existo', 'noexisto@mail.com'
END TRY
BEGIN CATCH
    SELECT 'P23 - Update cliente inexistente: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P24: Eliminar producto con ventas vinculadas (Trazabilidad)
BEGIN TRY
    EXEC sp_DeleteProducto 1
END TRY
BEGIN CATCH
    SELECT 'P24 - Trazabilidad producto: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH

-- P25: Stock inicial negativo
BEGIN TRY
    EXEC sp_InsertarProducto 'Error Stock', 10.00, 10.00, -5
END TRY
BEGIN CATCH
    SELECT 'P25 - Stock inicial negativo: ' + ERROR_MESSAGE() AS [RESULTADO_PRUEBA]
END CATCH


-- ----------------------------------------------------------
-- D. CONSULTAS FINALES DE VERIFICACIÓN DE ESTADO
-- ----------------------------------------------------------
PRINT '--- D. ESTADO FINAL DEL SISTEMA ---'

SELECT 'Estado final - Productos:' AS [Info];
EXEC sp_ListarProductos;

SELECT 'Estado final - Clientes:' AS [Info];
EXEC sp_ListarClientes;

SELECT 'Estado final - Pedidos registrados:' AS [Info];
SELECT * FROM Pedidos;

SELECT 'Estado final - Detalle de pedidos:' AS [Info];
SELECT * FROM Detalle_Pedido;

SELECT 'Reporte - Productos con stock bajo (< 3 unidades):' AS [Info];
EXEC sp_ReporteBajoStock;

SELECT 'Reporte - Ventas totales por cliente:' AS [Info];
EXEC sp_ReporteVentasPorCliente;