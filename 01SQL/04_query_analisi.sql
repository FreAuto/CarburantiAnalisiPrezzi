-- =====================================================================
--  03_query_analisi.sql – Prezzi dei carburanti in Italia ⛽
--  Database: carburanti.db (SQLite) · periodo: 28/07/2026 – 15/10/2026
--  Prezzi in euro al litro (metano in euro al kg), rilevati alle 8:00.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 🔎 0. CONOSCERE I DATI
-- ---------------------------------------------------------------------

-- Q01 · Quanti prezzi, distributori e giorni ci sono?
SELECT COUNT(*)                     AS prezzi,
       COUNT(DISTINCT id_impianto)  AS distributori,
       COUNT(DISTINCT data)         AS giorni,
       MIN(data)                    AS primo_giorno,
       MAX(data)                    AS ultimo_giorno
FROM prezzi;

-- Q02 · Quanti distributori vendono ogni carburante (ultimo giorno)?
SELECT carburante,
       COUNT(DISTINCT id_impianto) AS distributori
FROM prezzi
WHERE data = (SELECT MAX(data) FROM prezzi)
GROUP BY carburante
ORDER BY distributori DESC;


-- ---------------------------------------------------------------------
-- 📈 1. COME SONO CAMBIATI I PREZZI?
-- ---------------------------------------------------------------------

-- Q03 · Prezzo medio di ogni giorno: benzina e gasolio self
SELECT data,
       ROUND(AVG(CASE WHEN carburante = 'Benzina' THEN prezzo END), 3) AS benzina_self,
       ROUND(AVG(CASE WHEN carburante = 'Gasolio' THEN prezzo END), 3) AS gasolio_self
FROM prezzi
WHERE modalita = 'Self' AND carburante IN ('Benzina', 'Gasolio')
GROUP BY data
ORDER BY data;

-- Q04 · Variazione da un giorno all'altro (LAG) e media mobile di 7 giorni – benzina self
WITH giorni AS (
    SELECT data, AVG(prezzo) AS prezzo
    FROM prezzi
    WHERE carburante = 'Benzina' AND modalita = 'Self'
    GROUP BY data
)
SELECT data,
       ROUND(prezzo, 3)                                             AS prezzo_medio,
       ROUND(prezzo - LAG(prezzo) OVER (ORDER BY data), 3)          AS variazione_giorno,
       ROUND(AVG(prezzo) OVER (ORDER BY data ROWS 6 PRECEDING), 3)  AS media_mobile_7g
FROM giorni
ORDER BY data;

-- Q05 · Il giorno più caro e il più economico per ogni carburante
--       (benzina e gasolio self; GPL e metano servito, dove ci sono quasi tutti i prezzi)
WITH giorni AS (
    SELECT carburante, data, AVG(prezzo) AS prezzo
    FROM prezzi
    WHERE modalita = CASE WHEN carburante IN ('Benzina', 'Gasolio') THEN 'Self' ELSE 'Servito' END
    GROUP BY carburante, data
), classifica AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY carburante ORDER BY prezzo DESC) AS pos_caro,
              ROW_NUMBER() OVER (PARTITION BY carburante ORDER BY prezzo ASC)  AS pos_economico
    FROM giorni
)
SELECT carburante,
       MAX(CASE WHEN pos_caro = 1 THEN data END)                   AS giorno_piu_caro,
       ROUND(MAX(CASE WHEN pos_caro = 1 THEN prezzo END), 3)       AS prezzo_max,
       MAX(CASE WHEN pos_economico = 1 THEN data END)              AS giorno_piu_economico,
       ROUND(MAX(CASE WHEN pos_economico = 1 THEN prezzo END), 3)  AS prezzo_min
FROM classifica
GROUP BY carburante;

-- Q06 · Primo giorno contro ultimo giorno: di quanto sono cambiati i prezzi?
WITH estremi AS (
    SELECT carburante, modalita,
           AVG(CASE WHEN data = (SELECT MIN(data) FROM prezzi) THEN prezzo END) AS primo,
           AVG(CASE WHEN data = (SELECT MAX(data) FROM prezzi) THEN prezzo END) AS ultimo
    FROM prezzi
    GROUP BY carburante, modalita
)
SELECT carburante, modalita,
       ROUND(primo, 3)                            AS primo_giorno,
       ROUND(ultimo, 3)                           AS ultimo_giorno,
       ROUND(ultimo - primo, 3)                   AS differenza,
       ROUND(100.0 * (ultimo - primo) / primo, 1) AS variazione_pct
FROM estremi
ORDER BY carburante, modalita;

-- Q07 · Prezzo medio per settimana (benzina e gasolio self)
SELECT strftime('%W', data)  AS settimana,
       MIN(data)             AS dal,
       ROUND(AVG(CASE WHEN carburante = 'Benzina' THEN prezzo END), 3) AS benzina,
       ROUND(AVG(CASE WHEN carburante = 'Gasolio' THEN prezzo END), 3) AS gasolio
FROM prezzi
WHERE modalita = 'Self' AND carburante IN ('Benzina', 'Gasolio')
GROUP BY settimana
ORDER BY settimana;


-- ---------------------------------------------------------------------
-- 🙋 2. SELF O SERVITO?
-- ---------------------------------------------------------------------

-- Q08 · Quanto costa in più il servito? E su un pieno da 50 litri?
SELECT carburante,
       ROUND(AVG(CASE WHEN modalita = 'Servito' THEN prezzo END), 3) AS servito,
       ROUND(AVG(CASE WHEN modalita = 'Self'    THEN prezzo END), 3) AS self,
       ROUND(AVG(CASE WHEN modalita = 'Servito' THEN prezzo END)
           - AVG(CASE WHEN modalita = 'Self'    THEN prezzo END), 3) AS differenza_litro,
       ROUND(50 * (AVG(CASE WHEN modalita = 'Servito' THEN prezzo END)
                 - AVG(CASE WHEN modalita = 'Self'    THEN prezzo END)), 2) AS in_piu_su_50_litri
FROM prezzi
WHERE carburante IN ('Benzina', 'Gasolio')
GROUP BY carburante;


-- ---------------------------------------------------------------------
-- 🗺️ 3. DOVE COSTA DI PIÙ?
-- ---------------------------------------------------------------------

-- Q09 · Prezzo medio per zona d'Italia (benzina self, ultimo giorno)
SELECT zona,
       ROUND(AVG(prezzo), 3)        AS benzina_self,
       COUNT(DISTINCT id_impianto)  AS distributori
FROM v_prezzi
WHERE carburante = 'Benzina' AND modalita = 'Self'
  AND data = (SELECT MAX(data) FROM prezzi)
GROUP BY zona
ORDER BY benzina_self;

-- Q10 · Classifica delle regioni (benzina self, ultimo giorno)
SELECT RANK() OVER (ORDER BY AVG(prezzo)) AS posizione,
       regione,
       ROUND(AVG(prezzo), 3)              AS benzina_self,
       COUNT(*)                           AS distributori
FROM v_prezzi
WHERE carburante = 'Benzina' AND modalita = 'Self'
  AND data = (SELECT MAX(data) FROM prezzi)
GROUP BY regione
ORDER BY posizione;

-- Q11 · Le 5 province più economiche e le 5 più care (benzina self, ultimo giorno)
WITH prov AS (
    SELECT provincia, regione, AVG(prezzo) AS prezzo, COUNT(*) AS distributori
    FROM v_prezzi
    WHERE carburante = 'Benzina' AND modalita = 'Self'
      AND data = (SELECT MAX(data) FROM prezzi)
    GROUP BY provincia, regione
    HAVING COUNT(*) >= 20                 -- solo province con abbastanza distributori
), classifica AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY prezzo)      AS dal_basso,
              ROW_NUMBER() OVER (ORDER BY prezzo DESC) AS dall_alto
    FROM prov
)
SELECT CASE WHEN dal_basso <= 5 THEN '💚 economica' ELSE '🔴 cara' END AS gruppo,
       provincia, regione, ROUND(prezzo, 3) AS benzina_self, distributori
FROM classifica
WHERE dal_basso <= 5 OR dall_alto <= 5
ORDER BY prezzo;

-- Q12 · In quale regione i prezzi sono saliti di più? (benzina self, primo vs ultimo giorno)
WITH r AS (
    SELECT regione,
           AVG(CASE WHEN data = (SELECT MIN(data) FROM prezzi) THEN prezzo END) AS primo,
           AVG(CASE WHEN data = (SELECT MAX(data) FROM prezzi) THEN prezzo END) AS ultimo
    FROM v_prezzi
    WHERE carburante = 'Benzina' AND modalita = 'Self'
    GROUP BY regione
)
SELECT regione, ROUND(primo, 3) AS primo_giorno, ROUND(ultimo, 3) AS ultimo_giorno,
       ROUND(ultimo - primo, 3) AS aumento
FROM r
ORDER BY aumento DESC;

-- Q13 · Quanto si risparmia scegliendo il distributore giusto nella stessa provincia?
--       (10% più economico contro 10% più caro – benzina self, ultimo giorno)
WITH ultimo AS (
    SELECT provincia, prezzo,
           NTILE(10) OVER (PARTITION BY provincia ORDER BY prezzo) AS decile
    FROM v_prezzi
    WHERE carburante = 'Benzina' AND modalita = 'Self'
      AND data = (SELECT MAX(data) FROM prezzi)
)
SELECT provincia,
       ROUND(MAX(CASE WHEN decile = 1  THEN prezzo END), 3) AS economici_fino_a,
       ROUND(MIN(CASE WHEN decile = 10 THEN prezzo END), 3) AS cari_da,
       ROUND(50 * (MIN(CASE WHEN decile = 10 THEN prezzo END)
                 - MAX(CASE WHEN decile = 1  THEN prezzo END)), 2) AS risparmio_su_50_litri
FROM ultimo
GROUP BY provincia
HAVING COUNT(*) >= 50
ORDER BY risparmio_su_50_litri DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 🛣️ 4. AUTOSTRADA E MARCHI
-- ---------------------------------------------------------------------

-- Q14 · Autostrada contro strada normale
SELECT tipo_strada, carburante, modalita,
       ROUND(AVG(prezzo), 3)       AS prezzo_medio,
       COUNT(DISTINCT id_impianto) AS distributori
FROM v_prezzi
WHERE carburante IN ('Benzina', 'Gasolio')
GROUP BY tipo_strada, carburante, modalita
ORDER BY carburante, modalita, tipo_strada;

-- Q15 · Quanto costa in più l'autostrada su un pieno da 50 litri (self)?
WITH t AS (
    SELECT carburante,
           AVG(CASE WHEN tipo_strada = 'Autostradale' THEN prezzo END) AS autostrada,
           AVG(CASE WHEN tipo_strada = 'Stradale'     THEN prezzo END) AS strada
    FROM v_prezzi
    WHERE carburante IN ('Benzina', 'Gasolio') AND modalita = 'Self'
    GROUP BY carburante
)
SELECT carburante, ROUND(autostrada, 3) AS autostrada, ROUND(strada, 3) AS strada,
       ROUND(50 * (autostrada - strada), 2) AS in_piu_su_50_litri
FROM t;

-- Q16 · I marchi più grandi: quanti distributori e che prezzo (benzina self)
SELECT marchio,
       COUNT(DISTINCT id_impianto)         AS distributori,
       ROUND(AVG(prezzo), 3)               AS benzina_self,
       RANK() OVER (ORDER BY AVG(prezzo))  AS posizione_prezzo
FROM v_prezzi
WHERE carburante = 'Benzina' AND modalita = 'Self'
GROUP BY marchio
HAVING COUNT(DISTINCT id_impianto) >= 150
ORDER BY benzina_self;

-- Q17 · Pompe bianche (senza marchio) contro marchi famosi
SELECT CASE WHEN marchio LIKE 'Pompe bianche%' THEN 'Pompe bianche' ELSE 'Con marchio' END AS tipo,
       carburante,
       ROUND(AVG(prezzo), 3) AS self_medio
FROM v_prezzi
WHERE carburante IN ('Benzina', 'Gasolio') AND modalita = 'Self'
GROUP BY tipo, carburante
ORDER BY carburante, tipo;


-- ---------------------------------------------------------------------
-- 📅 5. CONVIENE UN GIORNO PRECISO?
-- ---------------------------------------------------------------------

-- Q18 · Prezzo medio per giorno della settimana (benzina self)
SELECT CASE strftime('%w', data)
            WHEN '1' THEN '1 Lunedì'  WHEN '2' THEN '2 Martedì' WHEN '3' THEN '3 Mercoledì'
            WHEN '4' THEN '4 Giovedì' WHEN '5' THEN '5 Venerdì' WHEN '6' THEN '6 Sabato'
            ELSE '7 Domenica' END AS giorno,
       ROUND(AVG(prezzo), 3)  AS benzina_self
FROM prezzi
WHERE carburante = 'Benzina' AND modalita = 'Self'
GROUP BY giorno
ORDER BY giorno;

-- Q19 · Quanti distributori cambiano prezzo ogni giorno? (benzina self)
WITH cambi AS (
    SELECT data, id_impianto, prezzo,
           LAG(prezzo) OVER (PARTITION BY id_impianto ORDER BY data) AS prima
    FROM prezzi
    WHERE carburante = 'Benzina' AND modalita = 'Self'
)
SELECT data,
       COUNT(*)                                          AS distributori,
       SUM(prezzo <> prima)                              AS hanno_cambiato,
       ROUND(100.0 * SUM(prezzo <> prima) / COUNT(*), 1) AS pct_cambiato
FROM cambi
WHERE prima IS NOT NULL
GROUP BY data
ORDER BY data;
