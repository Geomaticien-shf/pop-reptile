-- synthese.sql propre au protocole POPReptile.
-- Ce fichier a été généré à partir d'une copie du fichier synthese_svo.sql du module monitoring
-- (Vue générique pour alimenter la synthèse dans le cadre d'un protocole site-visite-observation)
--
-- Le fichier sera joué à l'installation avec la valeur de module_code qui sera attribué automatiquement
-- Il contient une variable :module_code (ou :'module_code')
-- utiliser psql avec l'option -v module_code=<module_code
-- Ne pas remplacer cette variable, elle est indispensable pour les scripts d'installations
-- le module pouvant être installé avec un code différent de l'original

DROP VIEW IF EXISTS gn_monitoring.v_synthese_:module_code;

CREATE OR REPLACE VIEW gn_monitoring.v_synthese_:module_code
AS WITH source AS (
         SELECT id_source
           FROM gn_synthese.t_sources
          WHERE name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
        )
 SELECT
    o.uuid_observation AS unique_id_sinp,
    v.uuid_base_visit AS unique_id_sinp_grp,
    (SELECT id_source FROM source) AS id_source,
    v.id_module as id_module,
    o.id_observation AS id_observation,
    o.id_observation AS entity_source_pk_value,
    v.id_dataset,
    ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'In') AS id_nomenclature_geo_object_nature,
    ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'PASS') AS id_nomenclature_grp_typ,
    -- Methode d'observation à vue, que ça soit sous plaque ou entre les plaques
    ref_nomenclatures.get_id_nomenclature('METH_OBS', '0') AS id_nomenclature_obs_technique,
    -- On ne renseigne pas le bio_status : on n'en dispose pas
    ref_nomenclatures.get_id_nomenclature('ETA_BIO', '1') as id_nomenclature_bio_condition,
    -- On ne renseigne pas la naturalness : on n'en dispose pas
    -- On regarde s'il existe des médias pour transmettre les preuves
    CASE
	WHEN unique_id_media IS NOT NULL THEN ref_nomenclatures.get_id_nomenclature('PREUVE_EXIST', '1')
	ELSE ref_nomenclatures.get_id_nomenclature('PREUVE_EXIST', '2')
    END AS id_nomenclature_exist_proof,
    ref_nomenclatures.get_id_nomenclature('OBJ_DENBR', 'IND') AS id_nomenclature_obj_count,
    nullif(json_extract_path(oc.data::json, 'id_nomenclature_type_denbr', 'null')::integer as id_nomenclature_type_count,
    nullif(json_extract_path(oc.data::json,'id_nomenclature_typ_denbr')::text, 'null')::integer as id_nomenclature_type_count,
    CASE
	WHEN oc.DATA->>'presence' = 'Non' THEN ref_nomenclatures.get_id_nomenclature('STATUT_OBS', 'No')
	ELSE ref_nomenclatures.get_id_nomenclature('STATUT_OBS', 'Pr')
    END as id_nomenclature_observation_status,
    ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status,
    ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type,
    nullif(json_extract_path(oc.data::json,'id_nomenclature_stade')::text, 'null')::integer AS id_nomenclature_life_stage,
    nullif(json_extract_path(oc.data::json,'id_nomenclature_sex')::text, 'null')::integer AS id_nomenclature_sex,
    nullif(json_extract_path(oc.data::json,'count_min')::text,'null')::integer AS count_min,
    nullif(json_extract_path(oc.data::json,'count_max')::text,'null')::integer AS count_max,
    o.cd_nom,
    t.nom_complet AS nom_cite,
    alt.altitude_min,
    alt.altitude_max,
    -- Eventuellement à adappter en fonction du système de projection du module monitoring et de la synthese
    -- En fonction, adapter les 3 géométries ci-dessous
    -- Par défaut, geom_local en lambert93 et geom en WGS84
    s.geom AS the_geom_4326,
    st_centroid(s.geom) AS the_geom_point,
    s.geom_local AS the_geom_local,
    -- FIXME: on pourrait ajouter les horaires de visite (champs complémentaires si remplis)
    v.visit_date_min AS date_min,
    v.visit_date_min AS date_max,
    obs.observers,
    v.id_digitiser,
    -- Examen visuel à "distance" (sans manipulation des individus)
    ref_nomenclatures.get_id_nomenclature('METH_DETERMIN', '18') AS id_nomenclature_determination_method,
    v.comments AS comment_context,
    o.comments AS comment_description,
    -- Les trois champs qui suivent ne sont pas utilisés mais peuvent faciliter les recherches / tris, donc on les mets dans la vue
    obs.ids_observers,
    v.id_base_site,
    v.id_base_visit,
    json_build_object(
	'methode_prospection', json_extract_path(vc.DATA::json, 'methode_prospection'),
        'expertise_operateur', json_extract_path(vc.DATA::json,'expertise'),
        'nom_aire', tsg.sites_group_name, 
        'description_aire', tsg.sites_group_description, 
        'habitat_principal_aire', json_extract_path(tsg.data::json,'habitat_principal')::text, 
        'commentaire_aire', tsg.comments, 
        'nom_transect', s.base_site_name, 
	'accessibiltie', json_extract_path(vc.DATA::json, 'accessibility'),
	'etat_site', json_extract_path(vc.DATA::json, 'etat_site'),
	'date_changement_etat_site', json_extract_path(vc.DATA::json, 'date_changement_etat_site'),
        'milieu_transect', json_extract_path(sc.data::json,'milieu_transect')::text, 
        'num_passage', json_extract_path(vc.data::json,'num_passage')::text, 
        'heure_debut', json_extract_path(vc.data::json,'Heure_debut')::text, 
        'heure_fin', json_extract_path(vc.data::json,'Heure_fin')::text
        ) as additional_data
   FROM gn_monitoring.t_base_visits v
     JOIN gn_monitoring.t_visit_complements vc on v.id_base_visit = vc.id_base_visit 
     JOIN gn_monitoring.t_base_sites s ON s.id_base_site = v.id_base_site
     JOIN gn_monitoring.t_site_complements sc on sc.id_base_site = s.id_base_site
     JOIN gn_monitoring.t_sites_groups tsg ON sc.id_sites_group = tsg.id_sites_group
     JOIN gn_commons.t_modules m ON m.id_module = v.id_module
     JOIN gn_monitoring.t_observations o ON o.id_base_visit = v.id_base_visit
     JOIN gn_monitoring.t_observation_complements oc ON oc.id_observation = o.id_observation
     LEFT JOIN gn_commons.t_medias tm ON (tm.id_table_location = gn_commons.get_table_location_id('gn_monitoring', 't_observations') AND tm.uuid_attached_row = o.uuid_observation)
     JOIN taxonomie.taxref t ON t.cd_nom = o.cd_nom
     LEFT JOIN LATERAL ( SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          WHERE cvo.id_base_visit = v.id_base_visit) obs ON true
     LEFT JOIN LATERAL ref_geo.fct_get_altitude_intersection(s.geom_local) alt(altitude_min, altitude_max) ON true
    WHERE m.module_code = :'module_code';
