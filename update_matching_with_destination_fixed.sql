-- Elimina TUTTE le vecchie versioni di find_compatible_trips e crea la nuova
-- con supporto per matching basato su destinazione finale

-- 1. ELIMINA tutte le vecchie versioni della funzione
DROP FUNCTION IF EXISTS find_compatible_trips(uuid);
DROP FUNCTION IF EXISTS find_compatible_trips(uuid, text);
DROP FUNCTION IF EXISTS find_compatible_trips(uuid, text, timestamp with time zone);
DROP FUNCTION IF EXISTS find_compatible_trips(uuid, text, timestamp with time zone, numeric, numeric, numeric);

-- 2. CREA la nuova versione con supporto destinazione
CREATE OR REPLACE FUNCTION find_compatible_trips(
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
    )::numeric as distance_km
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

    -- Destinazione finale entro il raggio specificato (default 5km)
    -- Usa formula haversine per calcolare distanza sulla sfera terrestre
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
    -- Ordina per distanza (più vicini prima)
    distance_km ASC,
    f.scheduled_arrival ASC;
END;
$$;

-- 3. Commento per documentazione
COMMENT ON FUNCTION find_compatible_trips IS
'Trova viaggi compatibili basandosi su:
1. Stesso aeroporto di arrivo
2. Orario arrivo entro ±30 minuti
3. Destinazione finale entro 5km (configurabile)
Restituisce anche la distanza in km tra le destinazioni.
Formula Haversine per calcolo distanza su sfera terrestre.';

-- 4. Grant permessi
GRANT EXECUTE ON FUNCTION find_compatible_trips(uuid, text, timestamp with time zone, numeric, numeric, numeric) TO authenticated;

-- 5. Verifica finale
DO $$
BEGIN
  RAISE NOTICE '✅✅✅ Funzione find_compatible_trips aggiornata!';
  RAISE NOTICE 'Vecchie versioni eliminate.';
  RAISE NOTICE 'Nuova versione con: aeroporto + orario + destinazione (max 5km)';
  RAISE NOTICE 'Formula Haversine per distanza accurata.';
END $$;
