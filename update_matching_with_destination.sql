-- Aggiorna funzione find_compatible_trips per considerare destinazione finale
-- Oltre ad aeroporto e orario, verifica che le destinazioni siano vicine (max 5km)

CREATE OR REPLACE FUNCTION find_compatible_trips(
  p_user_id uuid,
  p_arrival_airport text,
  p_scheduled_arrival timestamp with time zone,
  p_destination_lat numeric,
  p_destination_lng numeric,
  p_max_distance_km numeric DEFAULT 5.0  -- Massimo 5km tra destinazioni
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
        cos(radians(p_destination_lat)) *
        cos(radians(t.destination_lat)) *
        cos(radians(t.destination_lng) - radians(p_destination_lng)) +
        sin(radians(p_destination_lat)) *
        sin(radians(t.destination_lat))
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

    -- Destinazione finale entro il raggio specificato (default 5km)
    -- Usa formula haversine per calcolare distanza sulla sfera terrestre
    AND (
      6371 * acos(
        cos(radians(p_destination_lat)) *
        cos(radians(t.destination_lat)) *
        cos(radians(t.destination_lng) - radians(p_destination_lng)) +
        sin(radians(p_destination_lat)) *
        sin(radians(t.destination_lat))
      )
    ) <= p_max_distance_km

  ORDER BY
    -- Ordina per distanza (più vicini prima)
    distance_km ASC,
    f.scheduled_arrival ASC;
END;
$$;

-- Commento per documentazione
COMMENT ON FUNCTION find_compatible_trips IS
'Trova viaggi compatibili basandosi su:
1. Stesso aeroporto di arrivo
2. Orario arrivo entro ±30 minuti
3. Destinazione finale entro 5km (configurabile)
Restituisce anche la distanza in km tra le destinazioni.';

-- Grant permessi
GRANT EXECUTE ON FUNCTION find_compatible_trips(uuid, text, timestamp with time zone, numeric, numeric, numeric) TO authenticated;

-- Verifica
DO $$
BEGIN
  RAISE NOTICE '✅ Funzione find_compatible_trips aggiornata!';
  RAISE NOTICE 'Ora considera: aeroporto + orario + destinazione (max 5km)';
END $$;
