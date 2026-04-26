# EXP3_G5_MBD
Este sistema ha sido desarrollado como una solución integral para el control de inventarios y gestión de ventas, con un enfoque prioritario en la integridad referencial y lógica. El script automatiza desde la creación de la infraestructura de datos hasta la validación de reglas de negocio complejas mediante programación T-SQL.

# Experiencia 3: Modelamiento y Programación de BD - Grupo 5

## Resumen de Mejoras (Post-Asesoría)
Este proyecto fue rediseñado tras la asesoría técnica para elevar los estándares de integridad y seguridad de la base de datos. Las principales mejoras incluyen:

1. **Integridad de Datos:** Implementación de funciones de validación para formatos críticos (DUI salvadoreño, formato de Email y reglas de negocio).
2. **Manejo de Errores Profesional:** Uso de bloques `TRY...CATCH` y `THROW` con códigos de error personalizados para una respuesta clara del sistema.
3. **Protección de Trazabilidad:** Restricción de eliminación física para registros con historial transaccional (evita la pérdida de historial contable).
4. **Cálculos Automatizados:** Los precios de venta y subtotales se calculan dinámicamente mediante lógica interna del servidor.

---

## Estructura del Sistema

### **Capa de Datos (Tablas)**
* **Clientes:** Control de estado (Activo/Inactivo) y DUI como PK.
* **Productos:** Gestión de stock y márgenes de ganancia.
* **Ventas (Pedidos & Detalle):** Estructura normalizada para trazabilidad histórica.

### **Capa de Lógica (Funciones de Validación)**
* `fn_ValidarDUI`: Asegura el formato exacto de 10 caracteres.
* `fn_ValidarEmail`: Valida la estructura de correo electrónico.
* `fn_ValidaStock`: Protección preventiva antes de procesar ventas.
* `fn_ProductoActivo` / `fn_ClienteActivo`: Validación de estado lógico.

### **Capa Operativa (Procedimientos Almacenados)**
* **CRUD Completo:** Inserción, actualización y eliminación protegida. El procedimiento de borrado valida dependencias de llaves foráneas antes de ejecutar, asegurando que no se rompa la base de datos por accidente.
* **Proceso de Venta:** Procedimiento robusto que afecta múltiples tablas y valida integridad en una sola operación.
* **Reportes:** Consultas estratégicas para Stock Bajo y Ventas por Cliente.

---

## Batería de Pruebas
El script incluye una sección de **25 casos de prueba** documentados:
* **8 Casos de ror:** Validación de que el sistema bloquea correctamente datos corruptos o acciones no permitidas.
Éxito:** Verificación de flujos operacionales normales.
* **17 Casos de Error:** Validación de que el sistema bloquea correctamente datos corruptos o acciones no permitidas.
---

## ⚙️ Instrucciones de Uso
1. Ejecutar el script completo en **SQL Server Management Studio**.
2. El script se encarga de la creación de la BD, objetos y la ejecución automática de las pruebas.
