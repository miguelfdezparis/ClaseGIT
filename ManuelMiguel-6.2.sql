/*===================================
|| Bases de Datos - Miguel y Manuel ||
====================================*/
/*=============
||  BD WORLD  ||
==============*/

/*1. Crea una función que reciba el nombre de un país y devuelva cuántas ciudades del país hay.*/

CREATE OR REPLACE FUNCTION num_ciudades(p_nombre_pais TEXT)
RETURNS INTEGER
AS $$
DECLARE
    total INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO total
    FROM city c
    JOIN country co ON c.countrycode = co.code
    WHERE co.name = p_nombre_pais;

    RETURN total;
END;
$$ LANGUAGE plpgsql;

SELECT num_ciudades('Spain');

/*2. Crea una función que reciba el nombre de un idioma y devuelva en cuántos países se habla ese idioma.*/

CREATE OR REPLACE FUNCTION paises_idioma(p_idioma TEXT)
RETURNS INTEGER AS $$
DECLARE
    total INTEGER;
BEGIN
    SELECT COUNT(DISTINCT countrycode)
    INTO total
    FROM countrylanguage
    WHERE language = p_idioma;

    RETURN total;
END;
$$ LANGUAGE plpgsql;

SELECT paises_idioma('Spanish');

/*3. Crea una función que permita insertar nuevas ciudades en la base de datos.
  La función recibirá el nombre de la ciudad, el código del país, el distrito y la cantidad de habitantes.
  Debe devolver el id de la ciudad creada (utiliza returning).*/
CREATE SEQUENCE seq_city START 501 INCREMENT BY 1;
CREATE OR REPLACE FUNCTION insertar_ciudad(text,text,text,integer)
RETURNS INTEGER AS $$
DECLARE
    identif INT:=0;
BEGIN
    INSERT INTO city VALUES (NEXTVAL('seq_city'), $1,$2,$3,$4)
    RETURNING id INTO identif;
    RETURN identif;
END $$ LANGUAGE plpgsql;

SELECT insertar_ciudad('Melide', 'ESP', 'Galicia', 50000);

/*4. Realiza una función que permita modificar la población de una ciudad.
  Para ello no le daremos la población total, sino cuántos habitantes nuevos hay y cuántos habitantes se han ido
  (por ejemplo, hay 300 habitantes nuevos debidos a nacimientos e inmigración, y 180 habitantes menos
  debidos a defunciones y emigración). La función debe devolver la cantidad de habitantes actualizada.*/

CREATE OR REPLACE FUNCTION actualizar_poblacion(text,int,int)
RETURNS INTEGER AS $$
DECLARE
    pop INTEGER := 0;
BEGIN
    UPDATE city
    SET population = population + $2 - $3
    WHERE name = $1
    RETURNING population INTO pop;

    RETURN pop;
END $$ LANGUAGE plpgsql;

SELECT actualizar_poblacion('Vigo',500,200);

/*=============
||  BD HOTEL  ||
==============*/

/*5. Crea una función que reciba una fecha y devuelva la cantidad
  de huéspedes que allí había en el hotel en esa fecha.*/

CREATE OR REPLACE FUNCTION huespedes_en_fecha(p_fecha DATE)
RETURNS INTEGER AS $$
DECLARE
    total INTEGER;
BEGIN
    SELECT COUNT(DISTINCT customerid)
    INTO total
    FROM bookings
    WHERE p_fecha BETWEEN checkin AND checkout;

    RETURN COALESCE(total, 0);
END $$ LANGUAGE plpgsql;

SELECT huespedes_en_fecha('2021-01-10');

/*6. Crea una función que reciba un tipo y número de documento y
  nos devuelva en qué habitación está el huésped que tiene este
  documento (o NULL si en estos momentos no se encuentra en el hotel).*/

CREATE OR REPLACE FUNCTION habitacion_actual(
    p_tipo_doc VARCHAR,
    p_num_doc VARCHAR
)
RETURNS BIGINT AS $$
DECLARE
    hab BIGINT;
BEGIN
    SELECT s.roomnumber
    INTO hab
    FROM hosts h
    JOIN stayhosts sh ON h.id = sh.hostid
    JOIN stays s ON sh.stayid = s.id
    WHERE h.doctype = p_tipo_doc
      AND h.docnumber = p_num_doc
    ORDER BY s.checkout DESC
    LIMIT 1;

    RETURN hab;
END;
$$ LANGUAGE plpgsql;

SELECT habitacion_actual('National ID', '94971295654');

/*7. Crea una función que reciba el id de un tipo de habitación,
  una fecha de entrada y una fecha de salida, y nos devuelva un
  número de habitación que esté libre del tipo solicitado en estas fechas.
  Si hay muchas, haz que devuelva la que tenga un número más bajo.
  Si no hay ninguna habitación disponible, la función debe devolver NULL.*/

CREATE OR REPLACE FUNCTION habitacion_libre(
    p_roomtypeid BIGINT,
    p_fecha_ini DATE,
    p_fecha_fin DATE
)
RETURNS BIGINT AS $$
DECLARE
    hab BIGINT;
BEGIN
    SELECT r.roomnumber
    INTO hab
    FROM rooms r
    WHERE r.roomtypeid = p_roomtypeid
      AND r.roomnumber NOT IN (
        SELECT s.roomnumber
        FROM stays s
        WHERE p_fecha_ini <= s.checkout
          AND p_fecha_fin >= s.checkin
      )
    ORDER BY r.roomnumber
    LIMIT 1;

    RETURN hab;
END;
$$ LANGUAGE plpgsql;

SELECT habitacion_libre(1, '2025-07-01', '2025-07-05');

/*8. Crea una función que reciba el nombre de una temporada, el nombre de un
  tipo de habitación y un precio, y asigne el precio que recibe como precio
  del tipo de habitación especificado en la temporada especificada.
  La función devolverá el precio asignado.*/

CREATE OR REPLACE FUNCTION asignar_precio(
    p_season VARCHAR,
    p_roomtype VARCHAR,
    p_precio NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
    UPDATE priceseasons ps
    SET price = p_precio
    FROM roomtypes rt, seasons s
    WHERE ps.roomtypeid = rt.id
      AND ps.seasonid = s.id
      AND rt.name = p_roomtype
      AND s.name = p_season;

    RETURN p_precio;
END;
$$ LANGUAGE plpgsql;

SELECT asignar_precio('Verano', 'Doble', 150.00);

/*9. Crea una función que reciba el nombre de un tipo de habitación y el nombre
  de una característica (facility), y devuelva si el tipo de habitación tiene
  o no la característica en cuestión.*/

CREATE OR REPLACE FUNCTION tiene_caracteristica(
    p_roomtype VARCHAR,
    p_facility VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    existe BOOLEAN;
BEGIN
    SELECT TRUE
    INTO existe
    FROM roomtypes rt
    JOIN roomtypefacilities rtf ON rt.id = rtf.roomtypeid
    JOIN facilities f ON rtf.facilityid = f.id
    WHERE rt.name = p_roomtype
      AND f.name = p_facility
    LIMIT 1;

    RETURN COALESCE(existe, FALSE);
END;
$$ LANGUAGE plpgsql;

SELECT tiene_caracteristica('Doble', 'WiFi');

/*10. Crea una función que reciba un tipo y número de documento y nos devuelva
  la cantidad de noches que el huésped con este documento ha pasado al hotel.
  Debe devolver 0 si el huésped no existe en la base de datos.*/

CREATE OR REPLACE FUNCTION noches_huesped(
    p_tipo_doc VARCHAR,
    p_num_doc VARCHAR
)
RETURNS INTEGER AS $$
DECLARE
    total INTEGER;
BEGIN
    SELECT COALESCE(SUM(s.checkout - s.checkin), 0)
    INTO total
    FROM hosts h
    JOIN stayhosts sh ON h.id = sh.hostid
    JOIN stays s ON sh.stayid = s.id
    WHERE h.doctype = p_tipo_doc
      AND h.docnumber = p_num_doc;

    RETURN total;
END;
$$ LANGUAGE plpgsql;

SELECT noches_huesped('National ID', '949712956541');