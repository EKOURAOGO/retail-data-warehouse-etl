# Retail Data Warehouse — ETL Pipeline (MySQL)

Pipeline ETL en trois couches — staging, modèle en étoile, marts analytiques — appliqué aux données de vente retail multi-magasins. Implémente une dimension client en **SCD Type 2** réellement fonctionnelle (historique des changements de ville), orchestré par un script Python qui exécute les étapes dans l'ordre avec logs et mesure de temps. Validé par une suite de 18 tests qui vérifient la cohérence financière entre les couches, pas seulement l'absence d'erreur SQL.

---

## Pourquoi ce projet

Savoir écrire des requêtes analytiques ne suffit pas à démontrer une compétence en ingénierie de données : il faut aussi savoir **organiser l'architecture** qui rend ces requêtes rapides, fiables et historisées. Ce projet répond à la même question métier qu'un projet d'analyse directe ("quel est notre chiffre d'affaires par magasin") mais avec une architecture en couches typique d'un environnement d'entreprise — exactement le type de structure utilisée sur Databricks, Onyxia ou un data warehouse Snowflake/BigQuery.

---

## Architecture du pipeline

```
SOURCE (OLTP)              STAGING                 STAR SCHEMA              MARTS
─────────────────          ──────────────          ──────────────────       ──────────────────
retail_analytics      ──►  stg_* tables       ──►  dim_date                 mart_monthly_revenue
(sales_orders,             (copie brute,            dim_store                mart_customer_cohorts
 customers, products...)    traçabilité)             dim_employee             mart_product_performance
                                                      dim_product              mart_employee_performance
                                                      dim_customer (SCD2)      mart_customer_geography
                                                      fact_sales
```

| Couche | Rôle | Principe |
|--------|------|----------|
| **Staging** | Copie fidèle des tables sources | Aucune transformation, juste de la traçabilité (`_loaded_at`, `_source_table`) |
| **Star schema** | Modèle dimensionnel analytique | Clés de substitution, grain fixe (`fact_sales` = une ligne de commande), historique SCD2 sur le client |
| **Marts** | Vues métier prêtes pour la BI | Construites uniquement à partir du star schema, jamais du staging |

---

## Structure du projet

```
retail-dw/
├── 00_source_schema.sql            # Schéma de la base source (OLTP) — réutilisé du projet retail-analytics
├── 00_source_seed_data.sql         # Données source (909 commandes, 2258 lignes)
├── 01_staging_schema.sql           # 8 tables de staging avec colonnes de traçabilité
├── 02_etl_extract_to_staging.sql   # EXTRACT — source vers staging
├── 03_star_schema_ddl.sql          # 5 dimensions + 1 table de faits, avec clés étrangères
├── 04_etl_transform_load.sql       # TRANSFORM & LOAD — staging vers star schema
├── 05_etl_scd2_demo.sql            # Démonstration d'une mise à jour SCD2 réelle (changement de ville)
├── 06_marts_views.sql              # 5 vues analytiques construites sur le star schema
├── run_pipeline.py                 # Orchestrateur — exécute les 8 étapes dans l'ordre, avec logs
├── run_tests.sh                    # Suite de 18 tests de cohérence inter-couches
└── README.md
```

---

## Le mécanisme SCD Type 2 en détail

La dimension `dim_customer` ne se contente pas d'écraser la valeur de ville à chaque mise à jour — elle conserve l'historique complet :

```sql
-- Étape 1 : on ferme la version active
UPDATE dim_customer
SET valid_to = DATE_SUB(@change_date, INTERVAL 1 DAY), is_current = 0
WHERE customer_id = @target_customer_id AND is_current = 1;

-- Étape 2 : on insère la nouvelle version
INSERT INTO dim_customer (..., city, valid_from, valid_to, is_current)
VALUES (..., @new_city, @change_date, NULL, 1);
```

**Résultat vérifiable** après exécution de `05_etl_scd2_demo.sql` sur le client n°1 :

| customer_key | city | valid_from | valid_to | is_current |
|---|---|---|---|---|
| 1 | Nantes | 2022-04-25 | 2024-06-30 | 0 |
| 512 | Paris | 2024-07-01 | NULL | 1 |

Cela permet de répondre à deux questions différentes : *"où vit ce client aujourd'hui"* (`is_current = 1`) et *"où vivait-il quand il a passé telle commande historique"* (jointure sur la plage `valid_from` / `valid_to` correspondant à la date de la commande).

---

## Lancer le pipeline

```bash
python3 run_pipeline.py
```

Sortie attendue :

```
[00_source_schema] Create source OLTP database (retail_analytics)
  OK (0.25s)
[02_extract] EXTRACT — source -> staging
  OK (0.05s)
[04_transform_load] TRANSFORM & LOAD — staging -> star schema
  OK (6.63s)
...
PIPELINE COMPLETED SUCCESSFULLY in 7.32s
```

Ou étape par étape, en SQL pur :

```bash
mysql -u root < 00_source_schema.sql
mysql -u root < 00_source_seed_data.sql
mysql -u root < 01_staging_schema.sql
mysql -u root retail_dw < 02_etl_extract_to_staging.sql
mysql -u root retail_dw < 03_star_schema_ddl.sql
mysql -u root retail_dw < 04_etl_transform_load.sql
mysql -u root retail_dw < 05_etl_scd2_demo.sql
mysql -u root retail_dw < 06_marts_views.sql
```

---

## Lancer les tests

```bash
chmod +x run_tests.sh
./run_tests.sh
```

Les tests vérifient trois niveaux de garantie, pas seulement la syntaxe SQL :

| Niveau | Exemple de test |
|--------|------------------|
| Intégrité référentielle | Zéro ligne de `fact_sales` avec une clé de dimension non résolue |
| Cohérence financière | Le chiffre d'affaires total est identique au centime entre `stg_sales_order_items` et `fact_sales` |
| Logique SCD2 | Le client n°1 a exactement une version courante, et sa version historique a bien un `valid_to` renseigné |

Sortie attendue :

```
RESULTS: 18 passed, 0 failed
```

---

## Exemples de requêtes sur les marts

```sql
-- Chiffre d'affaires et marge par magasin et par mois
SELECT * FROM mart_monthly_revenue ORDER BY year, month_number;

-- Performance produit avec taux de retour
SELECT * FROM mart_product_performance ORDER BY total_revenue DESC;

-- Où vivent les clients aujourd'hui, et combien ont-ils dépensé au total
SELECT * FROM mart_customer_geography ORDER BY total_revenue DESC;
```

---

## Notes techniques

- `dim_date` est généré par une technique de *number generator* en SQL pur (sans table de séquence ni procédure stockée), produisant 366 lignes pour l'année bissextile 2024.
- Le coût et la marge de chaque ligne de vente (`line_cost`, `line_margin`) sont calculés **au moment du chargement** à partir du `unit_cost` courant du produit — une vraie volumétrie de production gérerait ici un SCD2 sur `dim_product` également, simplifié ici pour rester focalisé sur la démonstration SCD2 côté client.
- Le pipeline est idempotent par relance complète (chaque script commence par `DROP DATABASE IF EXISTS` au niveau staging), mais le script `05_etl_scd2_demo.sql` est conçu pour être un événement d'**incrémental load** : le rejouer une seconde fois créerait une troisième version, ce qui correspond exactement à un changement réel ultérieur du même client.

---

## Stack technique

![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=mysql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Star%20Schema%20·%20SCD2%20·%20ETL-blue?style=flat-square)
![Bash](https://img.shields.io/badge/Bash-Tests%20automatisés-4EAA25?style=flat-square&logo=gnubash&logoColor=white)

---

## Auteur

**Emmanuel KOURAOGO**

[GitHub](https://github.com/EKOURAOGO) · [Email](mailto:ekouraogo73@gmail.com)
