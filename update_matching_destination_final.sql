-- ELIMINA FORZATAMENTE tutte le versioni di find_compatible_trips
-- Poi crea la nuova versione con supporto destinazione

-- 1. Trova ed elimina TUTTE le versioni esistenti
-- Usa CASCADE per forzare l'eliminazione anche con dipendenze
DO $$
DECLARE
  func_signature text;
BEGIN
  -- Loop su tutte le funzioni chiamate find_compatible_trips
  FOR func_signature IN
    SELECT
      'DROP FUNCTION IF EXISTS ' ||
      oid::regprocedure::text ||
      ' CASCADE;'
    FROM pg_proc
    WHERE proname = 'find_compatible_trips'
  LOOP
    EXECUTE func_signature;
    RAISE NOTICE 'Deleted: %', func_signature;
  END LOOP;
END $$;

-- 2. Verifica che siano state eliminate
DO $$
DECLARE
  func_count integer;
BEGIN
  SELECT count(*) INTO func_count
  FROM pg_proc
  WHERE proname = 'find_compatible_trips';

  IF func_count > 0 THEN
    RAISE EXCEPTION 'Ancora % versioni di find_compatible_trips esistenti!', func_count;
  ELSE
    RAISE NOTICE '✅ Tutte le vecchie versioni eliminate con successo!';
  END IF;
END $$;

-- 3. CREA la nuova versione UNICA con supporto destinazione
CREATE FUNCTION find_compatible_trips(
  p_user_id uuid,
  p_arrival_airport text,
  p_scheduled_arrival timestamp with time zone,
  p_destination_lat numeric,
  p_destination_lng numeric,
  p_max_distance_km numeric DEFAULT 5.0
)
RETURNS TABLE(
  trip_id uuid,
  user_id uuid,
  flight_id uuid,
  arrival_airport text,
  scheduled_arrival timestamp with time zone,
  destination_lat numeric,
  destination_lng numeric,
  distance_km numeric
)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id as trip_id,
    t.user_id,
    t.flight_id,
    f.arrival_airport,
    f.scheduled_arrival,
    t.destination_lat,
    t.destination_lng,
    -- Calcola distanza in km usando formula haversine
    -- Usa LEAST/GREATEST per evitare errori con acos fuori range [-1, 1]
    ROUND(
      (
        6371 * acos(
          LEAST(1.0, GREATEST(-1.0,
            cos(radians(p_destination_lat::double precision)) *
            cos(radians(t.destination_lat::double precision)) *
            cos(radians(t.destination_lng::double precision) - radians(p_destination_lng::double precision)) +
            sin(radians(p_destination_lat::double precision)) *
            sin(radians(t.destination_lat::double precision))
          ))
        )
      )::numeric, 2
    ) as distance_km
  FROM trips t
  INNER JOIN flights f ON t.flight_id = f.id
  WHERE
    -- NON includere il viaggio dell'utente stesso
    t.user_id != p_user_id

    -- Stesso aeroporto di arrivo
    AND f.arrival_airport = p_arrival_airport

    -- Orario arrivo entro ±30 minuti
    AND f.scheduled_arrival BETWEEN
      (p_scheduled_arrival - INTERVAL '30 minutes') AND
      (p_scheduled_arrival + INTERVAL '30 minutes')

    -- Viaggio ancora valido (non cancellato)
    AND t.status != 'cancelled'

    -- Destinazione non NULL
    AND t.destination_lat IS NOT NULL
    AND t.destination_lng IS NOT NULL
    AND p_destination_lat IS NOT NULL
    AND p_destination_lng IS NOT NULL

    -- Destinazione finale entro il raggio specificato (default 5km)
    -- Calcola distanza e verifica che sia <= max_distance_km
    AND (
      6371 * acos(
        LEAST(1.0, GREATEST(-1.0,
          cos(radians(p_destination_lat::double precision)) *
          cos(radians(t.destination_lat::double precision)) *
          cos(radians(t.destination_lng::double precision) - radians(p_destination_lng::double precision)) +
          sin(radians(p_destination_lat::double precision)) *
          sin(radians(t.destination_lat::double precision))
        ))
      )
    ) <= p_max_distance_km

  ORDER BY
    -- Ordina per distanza (più vicini prima), poi per orario
    distance_km ASC,
    f.scheduled_arrival ASC;
END;
$$;

-- 4. Commenti e documentazione
COMMENT ON FUNCTION find_compatible_trips IS
'Trova viaggi compatibili considerando:
- Stesso aeroporto di arrivo
- Orario arrivo entro ±30 minuti
- Destinazione finale entro raggio specificato (default 5km)

Parametri:
- p_user_id: ID utente da escludere dai risultati
- p_arrival_airport: Aeroporto di arrivo (es. "Roma FCO")
- p_scheduled_arrival: Orario arrivo programmato
- p_destination_lat: Latitudine destinazione finale
- p_destination_lng: Longitudine destinazione finale
- p_max_distance_km: Raggio massimo in km (default 5.0)

Restituisce viaggi ordinati per distanza crescente con:
- trip_id, user_id, flight_id
- arrival_airport, scheduled_arrival
- destination_lat, destination_lng
- distance_km: distanza dalla destinazione utente

Formula: Haversine per distanza su sfera terrestre';

-- 5. Grant permessi
GRANT EXECUTE ON FUNCTION find_compatible_trips(uuid, text, timestamp with time zone, numeric, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION find_compatible_trips(uuid, text, timestamp with time zone, numeric, numeric, numeric) TO anon;

-- 6. Verifica finale
DO $$
DECLARE
  func_count integer;
BEGIN
  SELECT count(*) INTO func_count
  FROM pg_proc
  WHERE proname = 'find_compatible_trips';

  RAISE NOTICE '';
  RAISE NOTICE '════════════════════════════════════════════════════════';
  RAISE NOTICE '✅✅✅ FUNZIONE find_compatible_trips AGGIORNATA!';
  RAISE NOTICE '════════════════════════════════════════════════════════';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Numero versioni: %', func_count;
  RAISE NOTICE '✅ Vecchie versioni eliminate con CASCADE';
  RAISE NOTICE '✅ Nuova versione creata con supporto destinazione';
  RAISE NOTICE '';
  RAISE NOTICE '🎯 Matching ora considera:';
  RAISE NOTICE '   1. Aeroporto arrivo (stesso)';
  RAISE NOTICE '   2. Orario arrivo (±30 min)';
  RAISE NOTICE '   3. Destinazione finale (max 5km)';
  RAISE NOTICE '';
  RAISE NOTICE '📍 Formula Haversine per calcolo distanza accurata';
  RAISE NOTICE '🔒 Protezione contro errori acos fuori range';
  RAISE NOTICE '';
  RAISE NOTICE '════════════════════════════════════════════════════════';
END $$;
