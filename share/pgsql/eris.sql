--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: eris; Type: COMMENT; Schema: -; Owner: eris
--

COMMENT ON DATABASE eris IS 'This database inventories and archives significant network events for the eris monitoring system.';


--
-- Name: matviews; Type: SCHEMA; Schema: -; Owner: eris
--

CREATE SCHEMA matviews;


ALTER SCHEMA matviews OWNER TO eris;

--
-- Name: SCHEMA matviews; Type: COMMENT; Schema: -; Owner: eris
--

COMMENT ON SCHEMA matviews IS 'Special Schema for Materialized Views';


--
-- Name: plperlu; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres
--

CREATE OR REPLACE PROCEDURAL LANGUAGE plperlu;


ALTER PROCEDURAL LANGUAGE plperlu OWNER TO postgres;

--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres
--

CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres;

SET search_path = matviews, pg_catalog;

--
-- Name: create_matview(name, name); Type: FUNCTION; Schema: matviews; Owner: pg_admin
--

CREATE FUNCTION create_matview(name, name) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
 DECLARE
     matview ALIAS FOR $1;
     view_name ALIAS FOR $2;
     entry matviews.matviews%ROWTYPE;
 BEGIN
     SELECT * INTO entry FROM matviews.matviews WHERE mv_name = matview;
 
     IF FOUND THEN
         RAISE EXCEPTION 'Materialized view "%" already exists',
           matview;
     END IF;
 
     EXECUTE 'REVOKE ALL ON matviews.' || view_name || ' FROM PUBLIC'; 
     EXECUTE 'GRANT SELECT ON matviews.' || view_name || ' TO PUBLIC';
 
     EXECUTE 'CREATE TABLE public.' || matview || ' AS SELECT * FROM matviews.' || view_name;
     EXECUTE 'REVOKE ALL ON public.' || matview || ' FROM PUBLIC';
     EXECUTE 'GRANT SELECT ON public.' || matview || ' TO PUBLIC';
     EXECUTE 'ALTER TABLE public.' || matview || ' OWNER TO eris';
     EXECUTE 'GRANT ALL ON TABLE public.' || matview || ' TO eris';
 
     INSERT INTO matviews.matviews (mv_name, v_name, last_refresh)
       VALUES (matview, view_name, CURRENT_TIMESTAMP); 
     
     RETURN;
 END
 $_$;


ALTER FUNCTION matviews.create_matview(name, name) OWNER TO pg_admin;

--
-- Name: drop_matview(name); Type: FUNCTION; Schema: matviews; Owner: pg_admin
--

CREATE FUNCTION drop_matview(name) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
 DECLARE
     matview ALIAS FOR $1;
     entry matviews.matviews%ROWTYPE;
 BEGIN
 
     SELECT * INTO entry FROM matviews.matviews WHERE mv_name = matview;
 
     IF NOT FOUND THEN
         RAISE EXCEPTION 'Materialized view % does not exist.', matview;
     END IF;
 
     EXECUTE 'DROP TABLE public.' || matview;
     DELETE FROM matviews.matviews WHERE mv_name=matview;
 
     RETURN;
 END
 $_$;


ALTER FUNCTION matviews.drop_matview(name) OWNER TO pg_admin;

--
-- Name: refresh_matview(name); Type: FUNCTION; Schema: matviews; Owner: eris
--

CREATE FUNCTION refresh_matview(name) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
 DECLARE 
     matview ALIAS FOR $1;
     entry matviews.matviews%ROWTYPE;
 BEGIN
 
     SELECT * INTO entry FROM matviews.matviews WHERE mv_name = matview;
 
    IF NOT FOUND THEN
         RAISE EXCEPTION 'Materialized view % does not exist.', matview;
    END IF;

    IF entry.last_refresh > NOW() - entry.refresh_interval THEN
	RAISE EXCEPTION 'Materialized view % has not expired.', matview;
    END IF;

    EXECUTE 'DELETE FROM public.' || matview;
    EXECUTE 'INSERT INTO public.' || matview
        || ' SELECT * FROM matviews.' || entry.v_name;

    EXECUTE 'REINDEX TABLE ' || matview;

    UPDATE matviews.matviews
        SET last_refresh=NOW()
        WHERE mv_name=matview;

    RETURN;
END
$_$;


ALTER FUNCTION matviews.refresh_matview(name) OWNER TO eris;

SET search_path = public, pg_catalog;

--
-- Name: pl_get_fqdn(text); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION pl_get_fqdn(text) RETURNS text
    LANGUAGE plperlu
    AS $_$
use Socket;
use Regexp::Common qw(net);
my ($ip_str) = @_;

my $hostname = undef;
my $local = undef;

if( my ($ip) = ($ip_str =~ /$RE{net}{IPv4}{-keep}/) ) {
	$hostname = (gethostbyaddr(inet_aton($ip),AF_INET))[0];
	if( defined $hostname )  {
		($local) = ($hostname =~ /^([^\.]+)/);
	}
}
return $local;

$_$;


ALTER FUNCTION public.pl_get_fqdn(text) OWNER TO eris;

--
-- Name: pl_get_ip(character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION pl_get_ip(character varying) RETURNS inet
    LANGUAGE plperlu
    AS $_$use Socket;

my ($name) = @_;

# Sanitize
$name =~ s/[^\w\d\-\.]//;

my ($raw_addr) = (gethostbyname( $name ))[4];
my ($ip_addr) = undef;

if( defined $raw_addr ) {
	$ip_addr = inet_ntoa( $raw_addr );
}

return $ip_addr;$_$;


ALTER FUNCTION public.pl_get_ip(character varying) OWNER TO eris;

--
-- Name: plt_reverse_inventory(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION plt_reverse_inventory() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
        var_client_id character varying;
BEGIN

IF NEW.ip is not null and NEW.clientid is null THEN
   select pl_get_fqdn( CAST(NEW.ip as text) ) into var_client_id;
   NEW.clientid := var_client_id;
END IF;

NEW.clientid := lower( NEW.clientid );

RETURN NEW;

END;$$;


ALTER FUNCTION public.plt_reverse_inventory() OWNER TO eris;

--
-- Name: sp_add_device(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_add_device(in_clientid character varying, in_mac_addr character varying, in_ip_addr character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
	out_device_id integer := 0;
BEGIN
	insert into device_discovery ( clientid, mac_addr, ip_addr, discovery_method )
	values ( in_clientid, CAST(in_mac_addr as macaddr), CAST(in_ip_addr as inet), 'manual' );

	select currval('device_discovery_device_id_seq') into out_device_id;

	insert into inventory_archive ( device_id, mac_addr, ip_addr, clientid, discovery_method )
		values( out_device_id, CAST(in_mac_addr as macaddr), CAST(in_ip_addr as inet), in_clientid, 'manual' );
		
	return out_device_id;
END;$$;


ALTER FUNCTION public.sp_add_device(in_clientid character varying, in_mac_addr character varying, in_ip_addr character varying) OWNER TO eris;

--
-- Name: sp_dnsmgr_next_free_ip(integer, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_dnsmgr_next_free_ip(in_mgt_id integer, in_fqdn character varying) RETURNS inet
    LANGUAGE plpgsql
    AS $$DECLARE
	var_result_ip inet := null;
	var_ip inet;
	var_range_id integer := null;
	var_check integer;
	var_range RECORD;
BEGIN

FOR var_range in select * from dnsmgr_ip_mgt_range where mgt_id = in_mgt_id and range_used < range_total LOOP
	var_ip := var_range.range_start;
	var_range_id := var_range.range_id;
	WHILE var_ip <= var_range.range_stop LOOP
		SELECT count(1) into var_check from dnsmgr_ip_mgt_records where range_id = var_range.range_id and ip = var_ip;
		IF var_check = 0 THEN
			var_result_ip := var_ip;
			EXIT;
		ELSE
			var_ip := var_ip + 1;
		END IF;
	END LOOP;
	-- If we found an IP, exit this loop.
	IF var_result_ip is not null then
		EXIT;
	END IF;
END LOOP;

IF var_result_ip is null then
	RAISE EXCEPTION 'No free space in Management ID: %', in_mgt_id;
END IF;

-- Add a record so two requests don't take the same ip.
INSERT into dnsmgr_ip_mgt_records ( ip, fqdn, range_id, source )
	values ( var_result_ip, lower(in_fqdn), var_range_id, 'request' );

return var_result_ip;

END
$$;


ALTER FUNCTION public.sp_dnsmgr_next_free_ip(in_mgt_id integer, in_fqdn character varying) OWNER TO eris;

--
-- Name: sp_get_device_id(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_get_device_id(character varying, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
	in_mac_addr macaddr := CAST($1 as macaddr);
	in_clientid ALIAS FOR $2;
	in_discovery_method ALIAS FOR $3;
	output_device_id integer := 0;
BEGIN
	SELECT device_id into output_device_id from device_discovery
		where mac_addr = in_mac_addr;

	IF NOT FOUND THEN
		insert into device_discovery ( mac_addr, clientid, discovery_method )
			values ( in_mac_addr, in_clientid, in_discovery_method);
		select currval('device_discovery_device_id_seq') into output_device_id;
		insert into inventory_archive ( device_id, mac, clientid, discovery_method )
			values ( output_device_id, in_mac_addr, in_clientid, in_discovery_method );
	END IF;

	RETURN output_device_id;
END;$_$;


ALTER FUNCTION public.sp_get_device_id(character varying, character varying, character varying) OWNER TO eris;

--
-- Name: sp_get_signature_id(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_get_signature_id(in_facility character varying, in_native_sig_id character varying, in_description character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
	out_sig_id integer;
BEGIN
	select sig_id into out_sig_id from security_signatures
		where facility = in_facility and native_sig_id = in_native_sig_id;

	IF NOT FOUND THEN
		INSERT into security_signatures ( evt_type_id, native_sig_id, facility, description )
			values ( 1, in_native_sig_id, in_facility, in_description );
		select currval('security_signatures_sig_id_seq') into out_sig_id;
	END IF;

	RETURN out_sig_id;
END$$;


ALTER FUNCTION public.sp_get_signature_id(in_facility character varying, in_native_sig_id character varying, in_description character varying) OWNER TO eris;

--
-- Name: FUNCTION sp_get_signature_id(in_facility character varying, in_native_sig_id character varying, in_description character varying); Type: COMMENT; Schema: public; Owner: eris
--

COMMENT ON FUNCTION sp_get_signature_id(in_facility character varying, in_native_sig_id character varying, in_description character varying) IS 'Gets or Creates Signature ID for an Event';


--
-- Name: sp_get_weekid(character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_get_weekid(character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
	in_ts TIMESTAMP := CAST( $1 as TIMESTAMP );
	out_week_id INTEGER;
BEGIN

  select CAST( to_char(in_ts, 'YYYYWW') as integer ) into out_week_id;

  return out_week_id;

END;$_$;


ALTER FUNCTION public.sp_get_weekid(character varying) OWNER TO eris;

--
-- Name: sp_handle_arpwatch(character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_handle_arpwatch(character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE 
  in_ip inet := CAST($1 as inet);
  in_mac macaddr := CAST($2 as macaddr);
  in_timestamp timestamp := NOW();
  output_device_id INTEGER := 0;
  var_inv_id INTEGER := 0;
BEGIN
  select device_id into output_device_id
    from device_discovery
    where mac_addr = in_mac;

  IF NOT FOUND THEN
    insert into device_discovery
	( mac_addr, ip_addr, discovery_method, first_ts, last_ts )
      values 
	( in_mac, in_ip, 'arpwatch', in_timestamp, in_timestamp );
    select currval('device_discovery_device_id_seq')
      into output_device_id;
  ELSE
    update device_discovery
      set ip_addr = in_ip,
          discovery_method = 'arpwatch',
	  last_ts = in_timestamp
      where mac_addr = in_mac
	    and last_ts < in_timestamp;
  END IF;


  insert into inventory_archive ( device_id, mac, ip, event_ts, discovery_method )
	values ( output_device_id, in_mac, in_ip, in_timestamp, 'arpwatch' );

  RETURN output_device_id;

END;$_$;


ALTER FUNCTION public.sp_handle_arpwatch(character varying, character varying) OWNER TO eris;

--
-- Name: sp_handle_arpwatch(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_handle_arpwatch(character varying, character varying, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE 
  in_ip inet := CAST($1 as inet);
  in_mac macaddr := CAST($2 as macaddr);
  in_timestamp timestamp := CAST($3 as timestamp);
  in_clientid ALIAS FOR $4;
  output_device_id INTEGER := 0;
  var_inv_id INTEGER := 0;
BEGIN
  select device_id into output_device_id
    from device_discovery
    where mac_addr = in_mac;

  IF NOT FOUND THEN
    insert into device_discovery
	( mac_addr, ip_addr, clientid, discovery_method, first_ts, last_ts )
      values 
	( in_mac, in_ip, in_clientid, 'arpwatch', in_timestamp, in_timestamp );
    select currval('device_discovery_device_id_seq')
      into output_device_id;
  ELSE
    update device_discovery
      set ip_addr = in_ip,
          clientid = in_clientid,
          discovery_method = 'arpwatch',
	  last_ts = in_timestamp
      where mac_addr = in_mac
	    and last_ts < in_timestamp;
  END IF;

  select inv_archive_id into var_inv_id from inventory_archive
	where event_ts = in_timestamp and mac = in_mac and ip = in_ip;
  IF NOT FOUND THEN
	insert into inventory_archive ( device_id, mac, ip, clientid, event_ts, discovery_method )
		values ( output_device_id, in_mac, in_ip, in_clientid, in_timestamp, 'arpwatch' );
  END IF;

  RETURN output_device_id;

END;$_$;


ALTER FUNCTION public.sp_handle_arpwatch(character varying, character varying, character varying, character varying) OWNER TO eris;

--
-- Name: sp_handle_authentication(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_handle_authentication(character varying, in_username character varying, in_discovery_method character varying) RETURNS void
    LANGUAGE plpgsql
    AS $_$DECLARE
	in_ip_addr inet := CAST($1 as inet);
	var_device_id integer;
	var_user_id integer;
	var_authen_id integer;
BEGIN
	select device_id into var_device_id from device_discovery
		where last_ts > NOW() - interval '1 day'
		and ip_addr = in_ip_addr;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Unable to locate IP: %', in_ip_addr;
	END IF;

	select user_id into var_user_id from eris_users
		where lower(username) = lower(in_username);

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Unable to locate user: %', in_username;
	END IF;

	select authen_id into var_authen_id from authen_current
		where user_id = var_user_id and device_id = var_device_id;

	IF FOUND THEN
		update authen_current set
			last_ts = NOW(),
			discovery_method = in_discovery_method
		where authen_id = var_authen_id;
	ELSE
		insert into authen_current ( user_id, device_id, discovery_method )
			values ( var_user_id, var_device_id, in_discovery_method );
	END IF;

	insert into inventory_archive ( device_id, ip, username, user_id, discovery_method )
		values ( var_device_id, in_ip_addr, in_username, var_user_id, in_discovery_method );

	RETURN;
END;$_$;


ALTER FUNCTION public.sp_handle_authentication(character varying, in_username character varying, in_discovery_method character varying) OWNER TO eris;

--
-- Name: sp_handle_dhcpack(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_handle_dhcpack(character varying, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
  in_ip inet := CAST($1 as inet);
  in_mac macaddr := CAST($2 as macaddr);
  in_clientid ALIAS FOR $3;
  output_device_id INTEGER := 0;

BEGIN
  select device_id into output_device_id
    from device_discovery
    where mac_addr = in_mac;

  IF NOT FOUND THEN
    insert into device_discovery ( mac_addr, ip_addr, clientid, discovery_method )
      values ( in_mac, in_ip, in_clientid, 'dhcpack' );
    select currval('device_discovery_device_id_seq')
      into output_device_id;
  ELSE
    update device_discovery
      set ip_addr = in_ip,
          clientid = in_clientid,
          discovery_method = 'dhcpack'
      where mac_addr = in_mac;
  END IF;

  insert into inventory_archive ( device_id, mac, ip, clientid, discovery_method )
	values ( output_device_id, in_mac, in_ip, in_clientid, 'dhcpd' );

  RETURN output_device_id;
END;$_$;


ALTER FUNCTION public.sp_handle_dhcpack(character varying, character varying, character varying) OWNER TO eris;

--
-- Name: sp_handle_netdisco(character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, character varying); Type: FUNCTION; Schema: public; Owner: pg_admin
--

CREATE FUNCTION sp_handle_netdisco(character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, character varying) RETURNS void
    LANGUAGE plpgsql
    AS $_$DECLARE
	in_switch_ip INET := CAST($1 AS INET);
	in_port_num ALIAS FOR $2;
	in_mac macaddr := CAST($3 AS macaddr);
	in_first_ts ALIAS FOR $4;
	in_last_ts ALIAS FOR $5;
	in_vlan_spec ALIAS FOR $6;
	var_device_id INTEGER;
	var_switch_id INTEGER;
	var_type_id INTEGER;
	var_sp_id INTEGER;
	var_vlan_id INTEGER;
	var_vlan_discovery_id INTEGER;
BEGIN
	select device_id into var_switch_id from device_discovery
		where ip_addr = in_switch_ip;

	-- Find the switch
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Undiscovered switch: %', in_switch_ip;
	END IF;

	select node_type_id into var_type_id from device_details
		where device_id = var_switch_id;

	-- Make sure it's registered as a switch
	IF NOT FOUND THEN
		INSERT INTO device_details ( device_id, node_type_id, mod_ts )
			VALUES ( var_switch_id, 2, NOW() );
	ELSIF var_type_id not in ( 2, 6, 8 ) THEN
		RAISE EXCEPTION 'Device (%) is not registered as a switch!', in_switch_ip;
	END IF;

	-- Find the device!
	select device_id into var_device_id from device_discovery
		where mac_addr = in_mac;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Undiscovered device: %', in_mac;
	END IF;

	-- Set the VLAN ID
	select vlan_id into var_vlan_id from switch_vlans where vlan_specifier = in_vlan_spec;
	IF FOUND THEN
		select vlan_discovery_id into var_vlan_discovery_id from vlan_discovered
			where device_id = var_device_id and vlan_id = var_vlan_id;
		IF NOT FOUND THEN
		  update vlan_discovered set is_active = false where device_id = var_device_id and is_active is true;
		  insert into vlan_discovered ( device_id, vlan_id, discovery_method )
			values ( var_device_id, var_vlan_id, 'netdisco' );
		  else 
			update vlan_discovered set last_ts = NOW()
				where vlan_discovery_id = var_vlan_discovery_id;
		END IF;
	END IF;

	-- See if this is an update or delete:
	select sp_id into var_sp_id from switch_ports
		where device_id = var_device_id;

	IF NOT FOUND THEN
		INSERT INTO switch_ports ( switch_id, port_num, device_id, first_ts, last_ts )
			VALUES ( var_switch_id, in_port_num, var_device_id, in_first_ts, in_last_ts );
	ELSE
		UPDATE switch_ports set switch_id = var_switch_id,
					port_num = in_port_num,
					last_ts = in_last_ts
			where sp_id = var_sp_id;
	END IF;
	RETURN;
END;$_$;


ALTER FUNCTION public.sp_handle_netdisco(character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, character varying) OWNER TO pg_admin;

--
-- Name: sp_handle_service(character varying, character varying, integer, integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_handle_service(character varying, character varying, integer, integer, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
  in_ip inet := CAST($1 as inet);
  in_proto ALIAS for $2;
  in_port ALIAS for $3;
  in_conn ALIAS for $4;
  in_net ALIAS for $5;
  in_vicinity ALIAS for $6;
  out_svc_id integer;
  var_device_id integer;
BEGIN
  select device_id into var_device_id from device_discovery
    where ip_addr = in_ip;

  select svc_id into out_svc_id from services
    where (
          device_id = var_device_id or (device_id is null and ip = in_ip))
	and proto = in_proto
        and port = in_port;

   IF FOUND THEN
	update services set
		connections = connections + in_conn,
		last_ts = NOW()
	where svc_id = out_svc_id;
   ELSE
	insert into services ( device_id, ip, proto, port, connections, network_name, vicinity )
	    values ( var_device_id, in_ip, in_proto, in_port, in_conn, in_net, in_vicinity );
	select currval('services_svc_id_seq') into out_svc_id;
   END IF;
   
   RETURN out_svc_id;       
END;$_$;


ALTER FUNCTION public.sp_handle_service(character varying, character varying, integer, integer, character varying, character varying) OWNER TO eris;

--
-- Name: sp_lookup_device_id(character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_lookup_device_id(character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
	in_ipaddr inet := CAST($1 as inet);
	out_device_id INTEGER;
BEGIN
	SELECT device_id into out_device_id from device_discovery
		where ip_addr = in_ipaddr;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Unable to locate IP: %', in_ipaddr;
	END IF;

	RETURN out_device_id;
END$_$;


ALTER FUNCTION public.sp_lookup_device_id(character varying) OWNER TO eris;

--
-- Name: sp_reg_device(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_reg_device(character varying, character varying, character varying, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
	in_discovery_method ALIAS FOR $1;
	in_mac_addr macaddr := CAST($2 as macaddr);
	in_ip_addr inet := CAST($3 as inet);
	in_clientid ALIAS FOR $4;
	in_disc_ts TIMESTAMP := CAST($5 as timestamp);
	output_device_id integer;
	var_last_ts TIMESTAMP;
	var_inv_id integer;
BEGIN
	--validate discovery ts
	IF in_disc_ts is null then
		in_disc_ts := NOW();
	END IF;

	-- check to see if device exists
	select device_id, last_ts into output_device_id, var_last_ts from device_discovery
		where mac_addr = in_mac_addr;
		
	IF NOT FOUND THEN
		insert into device_discovery ( mac_addr, ip_addr, clientid, discovery_method )
			values ( in_mac_addr, in_ip_addr, in_clientid, in_discovery_method );
		select currval('device_discovery_device_id_seq') into output_device_id;
	ELSE
		-- Updates based on relevance
		IF in_disc_ts > var_last_ts THEN
			IF in_ip_addr is not null THEN
				update device_discovery set ip_addr = in_ip_addr
					where device_id = output_device_id;
			END IF;

			-- Discovery Columns
			update device_discovery set
				discovery_method = in_discovery_method,
				last_ts = in_disc_ts
			where device_id = output_device_id;
		END IF;

		-- Protected Column Updates
		update device_discovery set clientid = in_clientid where device_id = output_device_id;
	END IF;

	-- Register in device_inventory
	select inv_archive_id into var_inv_id from inventory_archive
		where device_id = output_device_id
		and discovery_method = in_discovery_method
		and event_ts = in_disc_ts;
	IF NOT FOUND THEN
		insert into inventory_archive ( device_id, mac, ip, clientid, discovery_method )
			values ( output_device_id, in_mac_addr, in_ip_addr, in_clientid, in_discovery_method );
	END IF;

	RETURN output_device_id;
END;$_$;


ALTER FUNCTION public.sp_reg_device(character varying, character varying, character varying, character varying, character varying) OWNER TO eris;

--
-- Name: sp_update_device_details(integer, integer, integer, integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION sp_update_device_details(in_mod_user_id integer, in_device_id integer, in_primary_user_id integer, in_node_type_id integer, in_property_tag character varying, in_make_model character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
   var_device_id integer := 0;
BEGIN
	select device_id into var_device_id from device_details
		where device_id = in_device_id;
		
	IF FOUND THEN
		update device_details set
			property_tag = in_property_tag,
			node_type_id = in_node_type_id,
			primary_user_id = in_primary_user_id,
			make_model = in_make_model,
			mod_user_id = in_mod_user_id,
			mod_ts = NOW()
		where device_id = in_device_id;
	ELSE
		insert into device_details ( device_id, property_tag, node_type_id, primary_user_id, make_model, mod_user_id )
			values( in_device_id, in_property_tag, in_node_type_id,  in_primary_user_id, in_make_model, in_mod_user_id );
	END IF;

	RETURN;
END;$$;


ALTER FUNCTION public.sp_update_device_details(in_mod_user_id integer, in_device_id integer, in_primary_user_id integer, in_node_type_id integer, in_property_tag character varying, in_make_model character varying) OWNER TO eris;

--
-- Name: tsp_device_details(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_device_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
        var_device_id integer := 0;
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.mod_ts := NOW();
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.mod_ts = NEW.mod_ts THEN
	NEW.mod_ts := NOW();
    END IF;
  END IF;

  RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_device_details() OWNER TO eris;

--
-- Name: tsp_device_discovery_ip(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_device_discovery_ip() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
  do_ip_check bool := false;
BEGIN
  IF TG_OP = 'INSERT' THEN
    do_ip_check := true;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.ip_addr is not null 
     AND NEW.ip_addr <> OLD.ip_addr THEN
      do_ip_check := true;
    END IF;
    IF NEW.last_ts = OLD.last_ts THEN
      NEW.last_ts := NOW();
    ELSIF NEW.last_ts < OLD.last_ts THEN
      NEW.last_ts := OLD.last_ts;
    END IF;
    IF ( OLD.clientid IS NOT NULL
       AND NEW.clientid IS NULL ) THEN
      NEW.clientid := OLD.clientid;
    END IF;
  END IF;

  NEW.clientid := lower( NEW.clientid );

  IF do_ip_check is true THEN
    update device_discovery
      set ip_addr = NULL
      where ip_addr = NEW.ip_addr
	and device_id <> NEW.device_id;
  END IF;
  RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_device_discovery_ip() OWNER TO eris;

--
-- Name: tsp_dns_queries(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_dns_queries() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_srv_id integer;
	var_cli_id integer;
BEGIN
  IF NEW.srv is not null THEN
	select device_id into var_srv_id from device_discovery
		where ip_addr = NEW.srv;
  END IF;

  IF NEW.cli is not null THEN
	select device_id into var_cli_id from device_discovery
		where ip_addr = NEW.cli;
  END IF;

  NEW.srv_id := var_srv_id;
  NEW.cli_id := var_cli_id;

  RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_dns_queries() OWNER TO eris;

--
-- Name: tsp_dnsmgr_ip_mgt_range(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_dnsmgr_ip_mgt_range() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_range_total INTEGER := 0;
BEGIN

var_range_total := NEW.range_stop - NEW.range_start + 1;

IF var_range_total > 0 THEN
  NEW.range_total := var_range_total;
END IF;

RETURN NEW;

END;$$;


ALTER FUNCTION public.tsp_dnsmgr_ip_mgt_range() OWNER TO eris;

--
-- Name: tsp_dnsmgr_ip_mgt_records_after(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_dnsmgr_ip_mgt_records_after() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_range_id INTEGER;
	var_range_used INTEGER := 0;
BEGIN

IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
	var_range_id := NEW.range_id;
ELSE 
	var_range_id := OLD.range_id;
END IF;

select count(1) into var_range_used from dnsmgr_ip_mgt_records where range_id = var_range_id;

update dnsmgr_ip_mgt_range set range_used = var_range_used where range_id = var_range_id;

RETURN NULL;

END;$$;


ALTER FUNCTION public.tsp_dnsmgr_ip_mgt_records_after() OWNER TO eris;

--
-- Name: tsp_dnsmgr_record_mgt_updater(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_dnsmgr_record_mgt_updater() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_class character(10);
	var_type character(10);
	var_zone character varying (255);
	var_clientid character varying (255);
	var_ip character varying (255);
	var_fqdn text;
	var_mgr_rec_id integer;
	var_rec_id integer;
	var_range_id integer;
BEGIN

-- Get the class/type/zone_id/clientid/ip of the record
IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
	var_class := NEW.class;
	var_type := NEW.type;
	var_ip := NEW.value;
	var_clientid := NEW.name;
	var_rec_id := NEW.record_id;
	select name into var_zone from dnsmgr_zones where zone_id = NEW.zone_id;
ELSIF TG_OP = 'DELETE' THEN
	var_class := OLD.class;
	var_type := OLD.type;
	var_clientid := OLD.name;
	var_ip := OLD.value;
	var_rec_id := OLD.record_id;
	select name into var_zone from dnsmgr_zones where zone_id = OLD.zone_id;
END IF;

-- Looking only at "IN A" entries for Record Management
IF var_class = 'IN' and var_type = 'A' THEN
	-- Select the Fully Qualified Domain Name
	var_fqdn := lower(var_clientid) || '.' || lower(var_zone);

	-- Select most specific range
	select range_id into var_range_id from dnsmgr_ip_mgt_range
		where var_ip::inet >= range_start and var_ip::inet <= range_stop
		order by range_stop - range_start ASC;
	
	-- Are we managing this range?
	IF var_range_id is not null THEN
		IF TG_OP = 'DELETE'THEN
			-- Do the Delete from records
			delete from dnsmgr_ip_mgt_records where range_id = var_range_id and fqdn = var_fqdn and ip = var_ip::inet;
		ELSIF TG_OP = 'INSERT' THEN
			-- Do the Insert
			insert into dnsmgr_ip_mgt_records ( range_id, fqdn, ip, forward_rec_id )
				values ( var_range_id, var_fqdn, var_ip::inet, var_rec_id );
		ELSIF TG_OP = 'UPDATE' THEN
			-- Update the record, by FQDN as "name" is the key in dnsmgr_records
			update dnsmgr_ip_mgt_records set range_id = var_range_id, ip = var_ip::inet
				where fqdn = var_fqdn and forward_rec_id = var_rec_id;
		END IF;
	END IF;
END IF;

RETURN NULL;
END;$$;


ALTER FUNCTION public.tsp_dnsmgr_record_mgt_updater() OWNER TO eris;

--
-- Name: tsp_dnsmgr_records_updater(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_dnsmgr_records_updater() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	do_mod boolean := false;
	mod_action character(3);
	mod_zone_id integer;
	mod_record_id bigint;
	mod_name character varying (255);
	mod_class character(10);
	mod_type character(10);
	mod_opt character varying (35);
	mod_value character varying (255);
	mod_req_user_id integer;
	mod_source character(5);
BEGIN
  IF TG_OP = 'INSERT' THEN
	mod_action := 'add';
	mod_zone_id := NEW.zone_id;
	mod_record_id := NEW.record_id;
	mod_name := NEW.name;
	mod_class := NEW.class;
	mod_type := NEW.type;
	mod_opt := NEW.opt;
	mod_value := NEW.value;
	mod_source := NEW.source;
	mod_req_user_id := NEW.mod_user_id;
	do_mod := true;
	
  ELSIF TG_OP = 'UPDATE' THEN
	mod_action := 'upd';
	mod_zone_id := NEW.zone_id;
	mod_record_id := NEW.record_id;
	mod_name := NEW.name;
	mod_class := NEW.class;
	mod_type := NEW.type;
	mod_opt := NEW.opt;
	mod_value := NEW.value;
	mod_source := NEW.source;
	mod_req_user_id := NEW.mod_user_id;

	IF OLD.value <> NEW.value THEN
		do_mod := true;
	ELSIF OLD.opt <> NEW.opt THEN
		do_mod := true;
	END IF;

	IF do_mod = true THEN
		NEW.mod_ts := NOW();
	END IF;

  ELSIF TG_OP = 'DELETE' THEN
	mod_action := 'del';
	mod_zone_id := OLD.zone_id;
	mod_record_id := OLD.record_id;
	mod_name := OLD.name;
	mod_class := OLD.class;
	mod_type := OLD.type;
	mod_opt := OLD.opt;
	mod_value := OLD.value;
	mod_source := OLD.source;
	mod_req_user_id := OLD.mod_user_id;
	do_mod := true;
	
  END IF;

  IF do_mod = true  THEN
	insert into dnsmgr_updates ( "zone_id", "record_id", "name", "class", "type", "opt", "value", "action", "source", "req_user_id" )
		values ( mod_zone_id, mod_record_id, mod_name, mod_class, mod_type, mod_opt, mod_value, mod_action, mod_source, mod_req_user_id ); 
  END IF;
  
  RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_dnsmgr_records_updater() OWNER TO eris;

--
-- Name: tsp_ext_custodian_user_id(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_ext_custodian_user_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_user_id INTEGER;
BEGIN

IF( NEW.custodian_name is not null) THEN
	select user_id into var_user_id from eris_users where display_name = NEW.custodian_name;
	NEW.user_id := var_user_id;
END IF;

RETURN NEW;

END;$$;


ALTER FUNCTION public.tsp_ext_custodian_user_id() OWNER TO eris;

--
-- Name: tsp_ext_pb_user_id(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_ext_pb_user_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_user_id INTEGER;
	var_device_id INTEGER;
BEGIN

IF( NEW.responsible_user is not null) THEN
	select user_id into var_user_id from eris_users where display_name = NEW.responsible_user;
	NEW.user_id := var_user_id;
END IF;

IF( NEW.property_tag is not null) THEN
	select device_id into var_device_id from device_details where property_tag = NEW.property_tag;
	NEW.device_id := var_device_id;
END IF;

RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_ext_pb_user_id() OWNER TO eris;

--
-- Name: tsp_fde_regulatory(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_fde_regulatory() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.mod_ts := NOW();
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.mod_ts = NEW.mod_ts THEN
	NEW.mod_ts := NOW();
    END IF;
  END IF;
  RETURN NEW;
END$$;


ALTER FUNCTION public.tsp_fde_regulatory() OWNER TO eris;

--
-- Name: tsp_map_device_status_insert(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_map_device_status_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN

IF TG_OP = 'INSERT' THEN
	update map_device_status set is_archived = true where device_id = NEW.device_id;
END IF;

RETURN NEW;

END;$$;


ALTER FUNCTION public.tsp_map_device_status_insert() OWNER TO eris;

--
-- Name: tsp_notification_email(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_notification_email() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.ack_code is null THEN
       NEW.ack_code := md5( NEW.email_id::text || NEW.user_id::text || NEW.notification_id::text || NEW.email_message::text );
    END IF;
  END IF;
  RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_notification_email() OWNER TO eris;

--
-- Name: tsp_notification_meta(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_notification_meta() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN

IF TG_OP = 'INSERT' THEN
	IF NEW.notification_interval is null THEN
		NEW.notification_interval := '30 days'::interval;
	END IF;

	NEW.last_interval_ts := NOW() - NEW.notification_interval;
END IF;

IF TG_OP = 'UPDATE' THEN

IF NEW.is_enabled is true and OLD.is_enabled is false THEN
	NEW.last_interval_ts := NOW();
END IF;

END IF;


RETURN NEW;

END;$$;


ALTER FUNCTION public.tsp_notification_meta() OWNER TO eris;

--
-- Name: tsp_notification_queue(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_notification_queue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_ntf_interval interval;
	var_start_ts timestamp without time zone;
	var_orig_email_id integer;
BEGIN

  IF TG_OP = 'INSERT' THEN
	select notification_interval into var_ntf_interval from notification_meta
		where notification_id = NEW.notification_id;
	var_start_ts := case when NEW.first_ts is not null then NEW.first_ts else NOW() end;
	NEW.expire_ts := var_start_ts + var_ntf_interval;

	select orig_email_id into var_orig_email_id from notification_queue
		where notification_id = NEW.notification_id and to_user_id = NEW.to_user_id
		order by first_ts desc limit 1;
	NEW.orig_email_id = var_orig_email_id;
  END IF;
  RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_notification_queue() OWNER TO eris;

--
-- Name: tsp_portable_cert_laptops_new(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_portable_cert_laptops_new() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_device_id INTEGER;
BEGIN

IF( NEW.property_tag is not null ) THEN
	select device_id into var_device_id from device_details where property_tag = NEW.property_tag;
	NEW.device_id := var_device_id;
END IF;

RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_portable_cert_laptops_new() OWNER TO eris;

--
-- Name: tsp_portable_devices_certify(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_portable_devices_certify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_user_id INTEGER;
	var_device_id INTEGER;

BEGIN

IF( NEW.username is not null ) THEN
	select user_id into var_user_id from eris_users where username = NEW.username;
	NEW.user_id := var_user_id;
END IF;

IF( NEW.remote_address is not null ) THEN
	select device_id into var_device_id from device_discovery where ip_addr = NEW.remote_address;
	NEW.device_id := var_device_id;
END IF;

NEW.entry_ts := NOW();

RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_portable_devices_certify() OWNER TO eris;

--
-- Name: FUNCTION tsp_portable_devices_certify(); Type: COMMENT; Schema: public; Owner: eris
--

COMMENT ON FUNCTION tsp_portable_devices_certify() IS 'Links Users and Devices to the rest of the Database.';


--
-- Name: tsp_security_events(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_security_events() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_sensor_ip inet;
	var_sensor_id integer;
	
	var_src_id integer;
	var_dst_id integer;
	
	var_src_user_id integer;
	var_dst_user_id integer;

	var_week_id char(6);
BEGIN

IF ( NEW.sensor is not null ) THEN
	select pl_get_ip( NEW.sensor ) into var_sensor_ip;
	IF var_sensor_ip is not null THEN
		select device_id into var_sensor_id from device_discovery
			where ip_addr = var_sensor_ip;
		NEW.sensor_id := var_sensor_id;
	END IF;
END IF;

IF( NEW.src_ip is not null ) THEN
	select device_id into var_src_id from device_discovery
		where ip_addr = NEW.src_ip;
	IF var_src_id IS NOT NULL THEN
		NEW.src_id := var_src_id;
		select user_id into var_src_user_id from inventory_archive
			where device_id = var_src_id
				and username is not null
				and event_ts > NOW() - interval '24 hours' 
			order by event_ts DESC limit 1;
		NEW.src_user_id := var_src_user_id;
	END IF;
END IF;

IF( NEW.dst_ip is not null ) THEN
	select device_id into var_dst_id from device_discovery
		where ip_addr = NEW.dst_ip;
	IF var_dst_id IS NOT NULL THEN
		NEW.dst_id := var_dst_id;
		select user_id into var_dst_user_id from inventory_archive
			where device_id = var_dst_id
				and username is not null
				and event_ts > NOW() - interval '24 hours'
			order by event_ts DESC limit 1;
		NEW.dst_user_id := var_dst_user_id;
	END IF;
END IF;

IF( NEW.src_username is not null ) THEN
	select user_id into var_src_user_id from eris_users
		where LOWER(username) = LOWER(NEW.src_username);
	NEW.src_user_id := var_src_user_id;
END IF;

IF( NEW.dst_username is not null ) THEN
	select user_id into var_dst_user_id from eris_users
		where LOWER(username) = LOWER(NEW.dst_username);
	NEW.dst_user_id := var_dst_user_id;
END IF;

select to_char(NEW.event_ts, 'YYYYWW') into var_week_id;
NEW.week_id := var_week_id;

RETURN NEW;
END$$;


ALTER FUNCTION public.tsp_security_events() OWNER TO eris;

--
-- Name: tsp_set_user_id(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_set_user_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	var_user_id INTEGER;
	var_device_id INTEGER;

BEGIN

IF( NEW.username is not null ) THEN
	select user_id into var_user_id from eris_users where username = NEW.username;
	NEW.user_id := var_user_id;
END IF;

RETURN NEW;

END;$$;


ALTER FUNCTION public.tsp_set_user_id() OWNER TO eris;

--
-- Name: tsp_switch_ports_check(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_switch_ports_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	do_type_check bool := false;
        var_type_id integer := 0;
BEGIN
  IF TG_OP = 'INSERT' THEN
    do_type_check := true;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.switch_id <> NEW.switch_id THEN
	do_type_check := true;
    END IF;
  END IF;

  IF do_type_check is true THEN
	select node_type_id into var_type_id from device_details
		where device_id = NEW.switch_id;

	IF NOT FOUND OR var_type_id not in ( 2, 6, 8 ) THEN
		RAISE EXCEPTION 'Device (id:%) is not a switch (type: %)', NEW.switch_id, var_type_id;
	END IF;
  END IF;
  RETURN NEW;
END;$$;


ALTER FUNCTION public.tsp_switch_ports_check() OWNER TO eris;

--
-- Name: tsp_ts2_syslog_archive(); Type: FUNCTION; Schema: public; Owner: eris
--

CREATE FUNCTION tsp_ts2_syslog_archive() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
  do_vectorize bool := false;
BEGIN

IF TG_OP = 'INSERT' THEN
  do_vectorize := true;
ELSIF TG_OP = 'UPDATE' THEN
  IF OLD.content <> NEW.content THEN
    do_vectorize := true;
   END IF;
END IF;

IF do_vectorize THEN
  NEW.vectors := to_tsvector(NEW.content);
END IF;

RETURN NEW;

END;$$;


ALTER FUNCTION public.tsp_ts2_syslog_archive() OWNER TO eris;

--
-- Name: FUNCTION tsp_ts2_syslog_archive(); Type: COMMENT; Schema: public; Owner: eris
--

COMMENT ON FUNCTION tsp_ts2_syslog_archive() IS 'Vectorize Inserts into the syslog_archive database';


SET search_path = matviews, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: matviews; Type: TABLE; Schema: matviews; Owner: eris; Tablespace: 
--

CREATE TABLE matviews (
    mv_name name NOT NULL,
    v_name name NOT NULL,
    last_refresh timestamp with time zone,
    refresh_interval interval DEFAULT '1 day'::interval NOT NULL,
    is_locked boolean DEFAULT false
);


ALTER TABLE matviews.matviews OWNER TO eris;

SET search_path = public, pg_catalog;

--
-- Name: security_event_types; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE security_event_types (
    evt_type_id integer NOT NULL,
    name character varying(40) NOT NULL,
    base_level integer DEFAULT 0,
    short character(20)
);


ALTER TABLE public.security_event_types OWNER TO eris;

--
-- Name: security_events; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE security_events (
    evt_id bigint NOT NULL,
    sensor character varying(255) NOT NULL,
    sensor_id integer,
    event_ts timestamp without time zone DEFAULT now(),
    src_ip inet,
    src_port integer,
    src_username character varying(30),
    src_user_id integer,
    src_id integer,
    dst_ip inet,
    dst_port integer,
    dst_username character varying(30),
    dst_user_id integer,
    dst_id integer,
    message text,
    sig_id integer NOT NULL,
    week_id character(6) DEFAULT 0 NOT NULL
);


ALTER TABLE public.security_events OWNER TO eris;

SET default_with_oids = true;

--
-- Name: security_signatures; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE security_signatures (
    sig_id integer NOT NULL,
    evt_type_id integer DEFAULT 1 NOT NULL,
    native_sig_id character varying(80) NOT NULL,
    facility character varying(40) NOT NULL,
    create_ts timestamp without time zone DEFAULT now(),
    description character varying(255)
);


ALTER TABLE public.security_signatures OWNER TO eris;

SET search_path = matviews, pg_catalog;

--
-- Name: v_security_events_7days; Type: VIEW; Schema: matviews; Owner: pg_admin
--

CREATE VIEW v_security_events_7days AS
    SELECT sigs.evt_type_id, evts.evt_id, evts.sensor, evts.sensor_id, evts.event_ts, evts.src_ip, evts.src_port, evts.src_username, evts.src_user_id, evts.src_id, evts.dst_ip, evts.dst_port, evts.dst_username, evts.dst_user_id, evts.dst_id, evts.message, evts.sig_id, evts.week_id FROM ((public.security_event_types evtype JOIN public.security_signatures sigs ON ((evtype.evt_type_id = sigs.evt_type_id))) JOIN public.security_events evts ON ((sigs.sig_id = evts.sig_id))) WHERE ((evtype.base_level > 1) AND (evts.event_ts > (now() - '7 days'::interval)));


ALTER TABLE matviews.v_security_events_7days OWNER TO pg_admin;

--
-- Name: v_security_offenders_sig_30days; Type: VIEW; Schema: matviews; Owner: eris
--

CREATE VIEW v_security_offenders_sig_30days AS
    SELECT CASE WHEN (evt.src_id IS NOT NULL) THEN evt.src_id ELSE evt.dst_id END AS offender_id, evt.sig_id, min(evt.event_ts) AS first_ts, max(evt.event_ts) AS last_ts, count(1) AS violations FROM public.security_events evt WHERE (((evt.src_id IS NOT NULL) OR (evt.dst_id IS NOT NULL)) AND (evt.event_ts > (now() - '30 days'::interval))) GROUP BY CASE WHEN (evt.src_id IS NOT NULL) THEN evt.src_id ELSE evt.dst_id END, evt.sig_id;


ALTER TABLE matviews.v_security_offenders_sig_30days OWNER TO eris;

SET search_path = public, pg_catalog;

SET default_with_oids = false;

--
-- Name: authen_current; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE authen_current (
    user_id integer NOT NULL,
    device_id integer NOT NULL,
    discovery_method character varying(25) NOT NULL,
    first_ts timestamp without time zone DEFAULT now(),
    last_ts timestamp without time zone DEFAULT now(),
    authen_id integer NOT NULL
);


ALTER TABLE public.authen_current OWNER TO eris;

--
-- Name: authen_current_authen_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE authen_current_authen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.authen_current_authen_id_seq OWNER TO eris;

--
-- Name: authen_current_authen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE authen_current_authen_id_seq OWNED BY authen_current.authen_id;


--
-- Name: device_class_mapping; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE device_class_mapping (
    device_id bigint,
    device_class_id integer,
    entry_ts timestamp without time zone DEFAULT now(),
    user_id integer
);


ALTER TABLE public.device_class_mapping OWNER TO eris;

--
-- Name: device_classes; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE device_classes (
    device_class_id integer NOT NULL,
    name character varying(80) NOT NULL,
    description text,
    type character varying(20) DEFAULT 'unknown'::character varying
);


ALTER TABLE public.device_classes OWNER TO eris;

--
-- Name: device_classes_device_class_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE device_classes_device_class_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.device_classes_device_class_id_seq OWNER TO eris;

--
-- Name: device_classes_device_class_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE device_classes_device_class_id_seq OWNED BY device_classes.device_class_id;


--
-- Name: device_details; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE device_details (
    device_id integer NOT NULL,
    property_tag character varying(25),
    node_type_id integer DEFAULT 1,
    mod_ts timestamp without time zone,
    mod_user_id integer,
    primary_user_id integer,
    make_model character varying(80),
    notes text,
    serial_no text
);


ALTER TABLE public.device_details OWNER TO eris;

--
-- Name: TABLE device_details; Type: COMMENT; Schema: public; Owner: eris
--

COMMENT ON TABLE device_details IS 'This holds all the user editable fields for the device discovery table.';


SET default_with_oids = true;

--
-- Name: device_discovery; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE device_discovery (
    device_id bigint NOT NULL,
    ip_addr inet,
    mac_addr macaddr NOT NULL,
    first_ts timestamp without time zone DEFAULT now() NOT NULL,
    last_ts timestamp without time zone DEFAULT now() NOT NULL,
    clientid character varying(150) DEFAULT 'unknown'::character varying,
    discovery_method character varying(20) DEFAULT 'unknown'::character varying,
    is_verified boolean DEFAULT false
);


ALTER TABLE public.device_discovery OWNER TO eris;

--
-- Name: device_discovery_device_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE device_discovery_device_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.device_discovery_device_id_seq OWNER TO eris;

--
-- Name: device_discovery_device_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE device_discovery_device_id_seq OWNED BY device_discovery.device_id;


SET default_with_oids = false;

--
-- Name: device_parents; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE device_parents (
    parent_id bigint NOT NULL,
    child_id bigint NOT NULL
);


ALTER TABLE public.device_parents OWNER TO eris;

--
-- Name: device_status; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE device_status (
    status_id integer NOT NULL,
    name character varying(25) NOT NULL,
    description text NOT NULL,
    is_operational boolean DEFAULT true NOT NULL,
    alarm_if_seen boolean DEFAULT false NOT NULL
);


ALTER TABLE public.device_status OWNER TO eris;

--
-- Name: device_status_status_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE device_status_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.device_status_status_id_seq OWNER TO eris;

--
-- Name: device_status_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE device_status_status_id_seq OWNED BY device_status.status_id;


--
-- Name: device_waivers; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE device_waivers (
    device_id bigint,
    waiver_id bigint
);


ALTER TABLE public.device_waivers OWNER TO eris;

--
-- Name: dnsmgr_ip_mgt; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE dnsmgr_ip_mgt (
    mgt_id integer NOT NULL,
    name character varying(25) NOT NULL,
    allow_edit boolean DEFAULT false NOT NULL,
    default_zone_id integer
);


ALTER TABLE public.dnsmgr_ip_mgt OWNER TO eris;

--
-- Name: dnsmgr_ip_mgt_mgt_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE dnsmgr_ip_mgt_mgt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dnsmgr_ip_mgt_mgt_id_seq OWNER TO eris;

--
-- Name: dnsmgr_ip_mgt_mgt_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE dnsmgr_ip_mgt_mgt_id_seq OWNED BY dnsmgr_ip_mgt.mgt_id;


--
-- Name: dnsmgr_ip_mgt_range; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE dnsmgr_ip_mgt_range (
    range_id integer NOT NULL,
    range_start inet NOT NULL,
    range_stop inet NOT NULL,
    mgt_id integer NOT NULL,
    range_total integer,
    range_used integer DEFAULT 0 NOT NULL,
    CONSTRAINT check_dnsmgr_ip_mgt_range CHECK ((range_stop >= range_start))
);


ALTER TABLE public.dnsmgr_ip_mgt_range OWNER TO eris;

--
-- Name: dnsmgr_ip_mgt_range_range_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE dnsmgr_ip_mgt_range_range_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dnsmgr_ip_mgt_range_range_id_seq OWNER TO eris;

--
-- Name: dnsmgr_ip_mgt_range_range_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE dnsmgr_ip_mgt_range_range_id_seq OWNED BY dnsmgr_ip_mgt_range.range_id;


--
-- Name: dnsmgr_ip_mgt_records; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE dnsmgr_ip_mgt_records (
    id bigint NOT NULL,
    ip inet NOT NULL,
    fqdn character varying(255),
    device_id integer,
    range_id integer NOT NULL,
    forward_rec_id integer,
    reverse_rec_id integer,
    source character varying(25) DEFAULT 'automatic'::character varying NOT NULL,
    first_ts timestamp without time zone DEFAULT now()
);


ALTER TABLE public.dnsmgr_ip_mgt_records OWNER TO eris;

--
-- Name: dnsmgr_ip_mgt_records_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE dnsmgr_ip_mgt_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dnsmgr_ip_mgt_records_id_seq OWNER TO eris;

--
-- Name: dnsmgr_ip_mgt_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE dnsmgr_ip_mgt_records_id_seq OWNED BY dnsmgr_ip_mgt_records.id;


--
-- Name: dnsmgr_records; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE dnsmgr_records (
    zone_id integer NOT NULL,
    record_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    class character(10) DEFAULT 'IN'::bpchar NOT NULL,
    type character(10),
    opt character varying(35),
    value character varying(255) NOT NULL,
    priority smallint DEFAULT 5 NOT NULL,
    parent_id bigint DEFAULT 0,
    mod_user_id integer,
    mod_ts timestamp without time zone DEFAULT now(),
    source character(5) DEFAULT 'user'::bpchar NOT NULL
);


ALTER TABLE public.dnsmgr_records OWNER TO eris;

--
-- Name: dnsmgr_records_record_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE dnsmgr_records_record_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dnsmgr_records_record_id_seq OWNER TO eris;

--
-- Name: dnsmgr_records_record_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE dnsmgr_records_record_id_seq OWNED BY dnsmgr_records.record_id;


--
-- Name: dnsmgr_updates; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE dnsmgr_updates (
    zone_id integer NOT NULL,
    record_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    class character(10) DEFAULT 'IN'::bpchar NOT NULL,
    type character(10) NOT NULL,
    opt character varying(35),
    value character varying(255) NOT NULL,
    request_ts timestamp without time zone DEFAULT now() NOT NULL,
    status_ts timestamp without time zone,
    status character(10),
    is_complete boolean DEFAULT false,
    req_user_id integer DEFAULT 0,
    update_id bigint NOT NULL,
    action character(3) DEFAULT 'add'::bpchar NOT NULL,
    source character(5) DEFAULT 'user'::bpchar
);


ALTER TABLE public.dnsmgr_updates OWNER TO eris;

--
-- Name: dnsmgr_updates_update_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE dnsmgr_updates_update_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dnsmgr_updates_update_id_seq OWNER TO eris;

--
-- Name: dnsmgr_updates_update_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE dnsmgr_updates_update_id_seq OWNED BY dnsmgr_updates.update_id;


--
-- Name: dnsmgr_zones; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE dnsmgr_zones (
    zone_id integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    type character(7) DEFAULT 'forward'::bpchar NOT NULL,
    accept character varying(20) DEFAULT 'any'::character varying NOT NULL,
    zone_priority integer DEFAULT 10 NOT NULL,
    accept_inet inet
);


ALTER TABLE public.dnsmgr_zones OWNER TO eris;

--
-- Name: dnsmgr_zones_zone_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE dnsmgr_zones_zone_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dnsmgr_zones_zone_id_seq OWNER TO eris;

--
-- Name: dnsmgr_zones_zone_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE dnsmgr_zones_zone_id_seq OWNED BY dnsmgr_zones.zone_id;


--
-- Name: eris_node_types; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE eris_node_types (
    node_type_id integer NOT NULL,
    name character varying(255) NOT NULL,
    short character varying(20),
    is_mobile boolean DEFAULT false,
    is_hub boolean DEFAULT false,
    has_parent boolean DEFAULT false NOT NULL
);


ALTER TABLE public.eris_node_types OWNER TO eris;

--
-- Name: eris_node_types_node_type_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE eris_node_types_node_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eris_node_types_node_type_id_seq OWNER TO eris;

--
-- Name: eris_node_types_node_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE eris_node_types_node_type_id_seq OWNED BY eris_node_types.node_type_id;


--
-- Name: eris_ous; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE eris_ous (
    ou_id integer NOT NULL,
    name character varying(255) NOT NULL,
    short character varying(20),
    external_code character varying(64)
);


ALTER TABLE public.eris_ous OWNER TO eris;

--
-- Name: eris_ous_ou_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE eris_ous_ou_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eris_ous_ou_id_seq OWNER TO eris;

--
-- Name: eris_ous_ou_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE eris_ous_ou_id_seq OWNED BY eris_ous.ou_id;


--
-- Name: eris_role_map; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE eris_role_map (
    role_id integer NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE public.eris_role_map OWNER TO eris;

--
-- Name: eris_roles; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE eris_roles (
    role_id integer NOT NULL,
    name character varying(25) NOT NULL
);


ALTER TABLE public.eris_roles OWNER TO eris;

--
-- Name: eris_roles_role_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE eris_roles_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eris_roles_role_id_seq OWNER TO eris;

--
-- Name: eris_roles_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE eris_roles_role_id_seq OWNED BY eris_roles.role_id;


--
-- Name: eris_users; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE eris_users (
    user_id bigint NOT NULL,
    username character varying(80),
    external_id character varying(25),
    email character varying(255),
    display_name character varying(255) NOT NULL,
    first_name character varying(120) NOT NULL,
    last_name character varying(134) NOT NULL,
    can_login boolean DEFAULT false,
    is_admin boolean DEFAULT false,
    is_active boolean DEFAULT false,
    orgid character varying(15),
    lab character varying(15),
    ext_last_logon_ts timestamp without time zone
);


ALTER TABLE public.eris_users OWNER TO eris;

--
-- Name: eris_users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE eris_users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eris_users_user_id_seq OWNER TO eris;

--
-- Name: eris_users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE eris_users_user_id_seq OWNED BY eris_users.user_id;


--
-- Name: ext_custodians; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE ext_custodians (
    uniq_id integer NOT NULL,
    custodial_code integer,
    user_id integer,
    custodian_name character varying(80)
);


ALTER TABLE public.ext_custodians OWNER TO eris;

--
-- Name: ext_custodians_uniq_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE ext_custodians_uniq_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ext_custodians_uniq_id_seq OWNER TO eris;

--
-- Name: ext_custodians_uniq_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE ext_custodians_uniq_id_seq OWNED BY ext_custodians.uniq_id;


--
-- Name: ext_lab_pco; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE ext_lab_pco (
    unique_id integer NOT NULL,
    lab character varying(15) NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE public.ext_lab_pco OWNER TO eris;

--
-- Name: ext_lab_pco_unique_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE ext_lab_pco_unique_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ext_lab_pco_unique_id_seq OWNER TO eris;

--
-- Name: ext_lab_pco_unique_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE ext_lab_pco_unique_id_seq OWNED BY ext_lab_pco.unique_id;


--
-- Name: ext_property_book; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE ext_property_book (
    property_tag character varying(15) NOT NULL,
    manufacturer character varying(35),
    model character varying(35),
    class_code character varying(15),
    class_name character varying(80),
    acquisition_date date,
    acquisition_cost numeric(8,2),
    last_inventory_date date,
    has_property_pass boolean DEFAULT false,
    responsible_user character varying(50),
    user_id integer,
    device_id integer,
    serial_number character varying(35),
    custodial_code integer,
    location character varying(35)
);


ALTER TABLE public.ext_property_book OWNER TO eris;

--
-- Name: ext_surplus_sheets; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE ext_surplus_sheets (
    property_tag character varying(10) NOT NULL
);


ALTER TABLE public.ext_surplus_sheets OWNER TO eris;

--
-- Name: fake_mac_addr; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE fake_mac_addr (
    suffix integer NOT NULL,
    create_ts timestamp without time zone DEFAULT now(),
    user_id integer
);


ALTER TABLE public.fake_mac_addr OWNER TO eris;

--
-- Name: fake_mac_addr_suffix_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE fake_mac_addr_suffix_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fake_mac_addr_suffix_seq OWNER TO eris;

--
-- Name: fake_mac_addr_suffix_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE fake_mac_addr_suffix_seq OWNED BY fake_mac_addr.suffix;


SET default_with_oids = true;

--
-- Name: inventory_archive; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE inventory_archive (
    inv_archive_id bigint NOT NULL,
    device_id bigint,
    user_id integer,
    mac macaddr,
    ip inet,
    clientid character varying(80),
    username character varying(80),
    event_ts timestamp without time zone DEFAULT now(),
    discovery_method character varying(80)
);


ALTER TABLE public.inventory_archive OWNER TO eris;

--
-- Name: inventory_archive_inv_archive_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE inventory_archive_inv_archive_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.inventory_archive_inv_archive_id_seq OWNER TO eris;

--
-- Name: inventory_archive_inv_archive_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE inventory_archive_inv_archive_id_seq OWNED BY inventory_archive.inv_archive_id;


SET default_with_oids = false;

--
-- Name: map_device_status; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE map_device_status (
    device_id bigint NOT NULL,
    status_id integer NOT NULL,
    mod_user_id integer NOT NULL,
    mod_ts timestamp without time zone DEFAULT now() NOT NULL,
    is_archived boolean DEFAULT false NOT NULL,
    map_id integer NOT NULL
);


ALTER TABLE public.map_device_status OWNER TO eris;

--
-- Name: map_device_status_map_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE map_device_status_map_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.map_device_status_map_id_seq OWNER TO eris;

--
-- Name: map_device_status_map_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE map_device_status_map_id_seq OWNED BY map_device_status.map_id;


--
-- Name: map_notification_email_rcpts; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE map_notification_email_rcpts (
    user_id integer NOT NULL,
    email_id integer NOT NULL,
    rcpt_type character(5) DEFAULT 'to'::bpchar NOT NULL
);


ALTER TABLE public.map_notification_email_rcpts OWNER TO eris;

--
-- Name: mv_security_offenders_sig_30days; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE mv_security_offenders_sig_30days (
    offender_id integer,
    sig_id integer,
    first_ts timestamp without time zone,
    last_ts timestamp without time zone,
    violations bigint
);


ALTER TABLE public.mv_security_offenders_sig_30days OWNER TO eris;

--
-- Name: notification_admins; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE notification_admins (
    notification_id integer NOT NULL,
    user_id integer NOT NULL,
    notify_admin_id bigint NOT NULL
);


ALTER TABLE public.notification_admins OWNER TO eris;

--
-- Name: notification_admins_notify_admin_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE notification_admins_notify_admin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_admins_notify_admin_id_seq OWNER TO eris;

--
-- Name: notification_admins_notify_admin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE notification_admins_notify_admin_id_seq OWNED BY notification_admins.notify_admin_id;


--
-- Name: notification_email; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE notification_email (
    email_id bigint NOT NULL,
    notification_id integer NOT NULL,
    user_id integer NOT NULL,
    sent_ts timestamp without time zone DEFAULT now(),
    email_type character(12) DEFAULT 'origination'::bpchar NOT NULL,
    email_subject character varying(255) NOT NULL,
    email_message text NOT NULL,
    ack_ts timestamp without time zone,
    ack_code character(40),
    file_id integer
);


ALTER TABLE public.notification_email OWNER TO eris;

--
-- Name: notification_email_email_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE notification_email_email_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_email_email_id_seq OWNER TO eris;

--
-- Name: notification_email_email_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE notification_email_email_id_seq OWNED BY notification_email.email_id;


--
-- Name: notification_files; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE notification_files (
    file_id bigint NOT NULL,
    filename character varying(255) NOT NULL,
    description text NOT NULL,
    filecontent bytea NOT NULL,
    filesize integer NOT NULL,
    filetype character varying(150) DEFAULT 'application/octet-stream'::character varying NOT NULL,
    notification_id integer
);


ALTER TABLE public.notification_files OWNER TO eris;

--
-- Name: notification_files_file_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE notification_files_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_files_file_id_seq OWNER TO eris;

--
-- Name: notification_files_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE notification_files_file_id_seq OWNED BY notification_files.file_id;


--
-- Name: notification_meta; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE notification_meta (
    notification_id bigint NOT NULL,
    evt_type_id integer NOT NULL,
    orig_admin_alert boolean DEFAULT false,
    orig_admin_message text,
    orig_user_alert boolean DEFAULT false,
    orig_user_message text,
    summary_admin_alert boolean DEFAULT false,
    summary_admin_message text,
    summary_user_alert boolean DEFAULT false,
    summary_user_message text,
    create_ts timestamp without time zone DEFAULT now(),
    mod_ts timestamp without time zone DEFAULT now(),
    mod_user_id integer,
    orig_admin_subject character varying(255),
    name character varying(100) NOT NULL,
    orig_user_subject character varying(100),
    summary_admin_subject character varying(100),
    summary_user_subject character varying(100),
    alert_from_address character varying(100),
    summary_last_ts timestamp without time zone,
    notification_interval interval DEFAULT '30 days'::interval,
    orig_user_file_id integer,
    is_enabled boolean DEFAULT true,
    min_events_trigger integer DEFAULT 1,
    last_interval_ts timestamp without time zone
);


ALTER TABLE public.notification_meta OWNER TO eris;

--
-- Name: notification_meta_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE notification_meta_notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_meta_notification_id_seq OWNER TO eris;

--
-- Name: notification_meta_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE notification_meta_notification_id_seq OWNED BY notification_meta.notification_id;


--
-- Name: notification_queue; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE notification_queue (
    queue_no bigint NOT NULL,
    notification_id integer NOT NULL,
    to_user_id integer NOT NULL,
    first_ts timestamp without time zone DEFAULT now(),
    last_ts timestamp without time zone DEFAULT now() NOT NULL,
    events integer,
    expire_ts timestamp without time zone NOT NULL,
    orig_email_id integer,
    summary_email_id integer
);


ALTER TABLE public.notification_queue OWNER TO eris;

--
-- Name: notification_queue_queue_no_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE notification_queue_queue_no_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_queue_queue_no_seq OWNER TO eris;

--
-- Name: notification_queue_queue_no_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE notification_queue_queue_no_seq OWNED BY notification_queue.queue_no;


--
-- Name: regulatory_application; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE regulatory_application (
    reg_app_id bigint NOT NULL,
    regulation_id integer NOT NULL,
    node_type_id integer NOT NULL
);


ALTER TABLE public.regulatory_application OWNER TO eris;

--
-- Name: regulatory_application_reg_app_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE regulatory_application_reg_app_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regulatory_application_reg_app_id_seq OWNER TO eris;

--
-- Name: regulatory_application_reg_app_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE regulatory_application_reg_app_id_seq OWNED BY regulatory_application.reg_app_id;


--
-- Name: regulatory_compliance; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE regulatory_compliance (
    reg_map_id bigint NOT NULL,
    regulation_id integer,
    device_id integer,
    mod_user_id integer,
    mod_ts timestamp without time zone DEFAULT now()
);


ALTER TABLE public.regulatory_compliance OWNER TO eris;

--
-- Name: regulatory_compliance_reg_map_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE regulatory_compliance_reg_map_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regulatory_compliance_reg_map_id_seq OWNER TO eris;

--
-- Name: regulatory_compliance_reg_map_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE regulatory_compliance_reg_map_id_seq OWNED BY regulatory_compliance.reg_map_id;


--
-- Name: regulatory_device_log; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE regulatory_device_log (
    reg_log_id bigint NOT NULL,
    regulation_id integer,
    entry_ts timestamp without time zone DEFAULT now(),
    user_id integer,
    device_id bigint,
    status character varying(15) NOT NULL,
    comments text
);


ALTER TABLE public.regulatory_device_log OWNER TO eris;

--
-- Name: regulatory_device_log_reg_log_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE regulatory_device_log_reg_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regulatory_device_log_reg_log_id_seq OWNER TO eris;

--
-- Name: regulatory_device_log_reg_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE regulatory_device_log_reg_log_id_seq OWNED BY regulatory_device_log.reg_log_id;


--
-- Name: regulatory_exception_classes; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE regulatory_exception_classes (
    reg_exp_id bigint NOT NULL,
    regulation_id integer NOT NULL,
    device_class_id integer NOT NULL,
    waiver_required boolean
);


ALTER TABLE public.regulatory_exception_classes OWNER TO eris;

--
-- Name: regulatory_exception_classes_reg_exp_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE regulatory_exception_classes_reg_exp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regulatory_exception_classes_reg_exp_id_seq OWNER TO eris;

--
-- Name: regulatory_exception_classes_reg_exp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE regulatory_exception_classes_reg_exp_id_seq OWNED BY regulatory_exception_classes.reg_exp_id;


--
-- Name: regulatory_meta; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE regulatory_meta (
    regulation_id integer NOT NULL,
    create_ts timestamp without time zone DEFAULT now(),
    initial_deadline date NOT NULL,
    waiver_correction_interval interval DEFAULT '30 days'::interval,
    name character varying(80) NOT NULL,
    description text
);


ALTER TABLE public.regulatory_meta OWNER TO eris;

--
-- Name: regulatory_meta_regulation_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE regulatory_meta_regulation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regulatory_meta_regulation_id_seq OWNER TO eris;

--
-- Name: regulatory_meta_regulation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE regulatory_meta_regulation_id_seq OWNED BY regulatory_meta.regulation_id;


--
-- Name: regulatory_waiver_log; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE regulatory_waiver_log (
    waiver_id bigint,
    entry_ts timestamp without time zone DEFAULT now(),
    user_id integer,
    status character varying(15) NOT NULL,
    comments text
);


ALTER TABLE public.regulatory_waiver_log OWNER TO eris;

--
-- Name: regulatory_waivers; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE regulatory_waivers (
    meta_waiver_id integer,
    waiver_id bigint NOT NULL,
    create_ts timestamp without time zone DEFAULT now(),
    close_ts timestamp without time zone DEFAULT now(),
    status character varying(15) NOT NULL
);


ALTER TABLE public.regulatory_waivers OWNER TO eris;

--
-- Name: regulatory_waivers_meta; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE regulatory_waivers_meta (
    meta_waiver_id integer NOT NULL,
    regulation_id integer,
    exception_class_id integer,
    description text,
    compensating_controls text,
    authoritative_user_id integer,
    destination_fax character varying(20),
    destination_email character varying(255),
    is_active boolean DEFAULT true
);


ALTER TABLE public.regulatory_waivers_meta OWNER TO eris;

--
-- Name: regulatory_waivers_meta_meta_waiver_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE regulatory_waivers_meta_meta_waiver_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regulatory_waivers_meta_meta_waiver_id_seq OWNER TO eris;

--
-- Name: regulatory_waivers_meta_meta_waiver_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE regulatory_waivers_meta_meta_waiver_id_seq OWNED BY regulatory_waivers_meta.meta_waiver_id;


--
-- Name: regulatory_waivers_waiver_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE regulatory_waivers_waiver_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regulatory_waivers_waiver_id_seq OWNER TO eris;

--
-- Name: regulatory_waivers_waiver_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE regulatory_waivers_waiver_id_seq OWNED BY regulatory_waivers.waiver_id;


--
-- Name: security_event_types_evt_type_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE security_event_types_evt_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.security_event_types_evt_type_id_seq OWNER TO eris;

--
-- Name: security_event_types_evt_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE security_event_types_evt_type_id_seq OWNED BY security_event_types.evt_type_id;


--
-- Name: security_events_evt_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE security_events_evt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.security_events_evt_id_seq OWNER TO eris;

--
-- Name: security_events_evt_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE security_events_evt_id_seq OWNED BY security_events.evt_id;


--
-- Name: security_signatures_sig_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE security_signatures_sig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.security_signatures_sig_id_seq OWNER TO eris;

--
-- Name: security_signatures_sig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE security_signatures_sig_id_seq OWNED BY security_signatures.sig_id;


--
-- Name: services; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE services (
    svc_id bigint NOT NULL,
    device_id integer,
    ip inet,
    proto character varying(10),
    port integer,
    connections bigint,
    first_ts timestamp without time zone DEFAULT now(),
    last_ts timestamp without time zone DEFAULT now(),
    network_name character varying(20) DEFAULT 'lan'::character varying NOT NULL,
    vicinity character varying(10) DEFAULT 'internal'::character varying NOT NULL
);


ALTER TABLE public.services OWNER TO eris;

--
-- Name: services_svc_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE services_svc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.services_svc_id_seq OWNER TO eris;

--
-- Name: services_svc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE services_svc_id_seq OWNED BY services.svc_id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE sessions (
    id character(72) NOT NULL,
    session_data text,
    creation timestamp without time zone DEFAULT now(),
    expires integer
);


ALTER TABLE public.sessions OWNER TO eris;

--
-- Name: switch_ports; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE switch_ports (
    switch_id integer NOT NULL,
    port_num character varying(30) NOT NULL,
    device_id integer NOT NULL,
    first_ts timestamp without time zone DEFAULT now(),
    last_ts timestamp without time zone DEFAULT now(),
    sp_id integer NOT NULL,
    vlan_id integer
);


ALTER TABLE public.switch_ports OWNER TO eris;

--
-- Name: TABLE switch_ports; Type: COMMENT; Schema: public; Owner: eris
--

COMMENT ON TABLE switch_ports IS 'This table stores Switch and Port relations.';


--
-- Name: switch_ports_sp_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE switch_ports_sp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.switch_ports_sp_id_seq OWNER TO eris;

--
-- Name: switch_ports_sp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE switch_ports_sp_id_seq OWNED BY switch_ports.sp_id;


--
-- Name: switch_vlans; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE switch_vlans (
    vlan_id integer NOT NULL,
    vlan_specifier character varying(25) NOT NULL,
    vlan_name character varying(80) NOT NULL,
    vlan_type character varying(80),
    nac_managed boolean DEFAULT false NOT NULL,
    nac_specifier character varying(40),
    description text
);


ALTER TABLE public.switch_vlans OWNER TO eris;

--
-- Name: switch_vlans_vlan_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE switch_vlans_vlan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.switch_vlans_vlan_id_seq OWNER TO eris;

--
-- Name: switch_vlans_vlan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE switch_vlans_vlan_id_seq OWNED BY switch_vlans.vlan_id;


--
-- Name: syslog_archive; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE syslog_archive (
    priority character varying(10) NOT NULL,
    priority_int integer NOT NULL,
    facility character varying(15) NOT NULL,
    facility_int integer NOT NULL,
    event_ts timestamp without time zone NOT NULL,
    hostname character varying(80) NOT NULL,
    domain character varying(255),
    program_name character varying(25),
    program_pid integer,
    program_sub character varying(25),
    content text NOT NULL,
    entry_ts timestamp without time zone DEFAULT now() NOT NULL,
    message_id bigint NOT NULL
);


ALTER TABLE public.syslog_archive OWNER TO eris;

--
-- Name: syslog_archive_message_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE syslog_archive_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.syslog_archive_message_id_seq OWNER TO eris;

--
-- Name: syslog_archive_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE syslog_archive_message_id_seq OWNED BY syslog_archive.message_id;


--
-- Name: v_admin_index_usage; Type: VIEW; Schema: public; Owner: eris
--

CREATE VIEW v_admin_index_usage AS
    SELECT t.relname AS "table", c.relname AS index_name, c.relpages, i.idx_scan, t.seq_scan FROM ((pg_class c JOIN pg_stat_user_indexes i ON ((c.relname = i.indexrelname))) JOIN pg_stat_user_tables t ON ((i.relname = t.relname))) ORDER BY c.relpages DESC;


ALTER TABLE public.v_admin_index_usage OWNER TO eris;

--
-- Name: v_daily_authentication; Type: VIEW; Schema: public; Owner: eris
--

CREATE VIEW v_daily_authentication AS
    SELECT dd.device_id, eu.username, eu.display_name, eu.email, ac.discovery_method AS auth_method, ac.last_ts AS auth_ts, dd.ip_addr AS ip, dd.mac_addr AS mac, dd.clientid, dd.last_ts AS device_ts, dd.discovery_method AS device_method, sw.ip_addr AS switch_ip, sp.port_num AS switch_port FROM ((((device_discovery dd LEFT JOIN authen_current ac ON ((dd.device_id = ac.device_id))) LEFT JOIN eris_users eu ON ((ac.user_id = eu.user_id))) LEFT JOIN switch_ports sp ON ((dd.device_id = sp.device_id))) LEFT JOIN device_discovery sw ON ((sp.switch_id = sw.device_id))) WHERE (((ac.last_ts IS NOT NULL) AND (ac.last_ts > (now() - '24:00:00'::interval))) OR ((dd.last_ts IS NOT NULL) AND (dd.last_ts > (now() - '1 day'::interval))));


ALTER TABLE public.v_daily_authentication OWNER TO eris;

--
-- Name: v_device_overview; Type: VIEW; Schema: public; Owner: eris
--

CREATE VIEW v_device_overview AS
    SELECT dd.device_id, dd.ip_addr AS ip, dd.mac_addr AS mac, dd.clientid, dd.last_ts AS device_ts, dd.discovery_method AS device_method, det.property_tag, det.make_model, ent.short AS device_type, sw.device_id AS switch_id, sw.ip_addr AS switch_ip, sp.port_num AS switch_port FROM ((((device_discovery dd LEFT JOIN switch_ports sp ON ((dd.device_id = sp.device_id))) LEFT JOIN device_discovery sw ON ((sp.switch_id = sw.device_id))) LEFT JOIN device_details det ON ((dd.device_id = det.device_id))) LEFT JOIN eris_node_types ent ON ((det.node_type_id = ent.node_type_id))) WHERE (dd.last_ts IS NOT NULL);


ALTER TABLE public.v_device_overview OWNER TO eris;

--
-- Name: v_history_auth; Type: VIEW; Schema: public; Owner: eris
--

CREATE VIEW v_history_auth AS
    SELECT inventory_archive.device_id, inventory_archive.user_id, inventory_archive.ip, inventory_archive.username, inventory_archive.event_ts, inventory_archive.discovery_method FROM inventory_archive WHERE ((inventory_archive.ip IS NOT NULL) AND (inventory_archive.username IS NOT NULL));


ALTER TABLE public.v_history_auth OWNER TO eris;

--
-- Name: v_history_node; Type: VIEW; Schema: public; Owner: eris
--

CREATE VIEW v_history_node AS
    SELECT inventory_archive.device_id, inventory_archive.mac, inventory_archive.ip, inventory_archive.clientid, inventory_archive.event_ts, inventory_archive.discovery_method FROM inventory_archive WHERE ((inventory_archive.mac IS NOT NULL) AND (inventory_archive.ip IS NOT NULL));


ALTER TABLE public.v_history_node OWNER TO eris;

--
-- Name: v_security_offenders_bytype; Type: VIEW; Schema: public; Owner: eris
--

CREATE VIEW v_security_offenders_bytype AS
    SELECT sig.evt_type_id, CASE WHEN (evt.src_id IS NOT NULL) THEN evt.src_ip WHEN (evt.dst_id IS NOT NULL) THEN evt.dst_ip ELSE NULL::inet END AS offending_ip, CASE WHEN (evt.src_id IS NOT NULL) THEN evt.src_id WHEN (evt.dst_id IS NOT NULL) THEN evt.dst_id ELSE NULL::integer END AS offending_id, count(1) AS violations FROM (security_events evt JOIN security_signatures sig ON ((evt.sig_id = sig.sig_id))) WHERE (evt.event_ts > (now() - '30 days'::interval)) GROUP BY sig.evt_type_id, CASE WHEN (evt.src_id IS NOT NULL) THEN evt.src_ip WHEN (evt.dst_id IS NOT NULL) THEN evt.dst_ip ELSE NULL::inet END, CASE WHEN (evt.src_id IS NOT NULL) THEN evt.src_id WHEN (evt.dst_id IS NOT NULL) THEN evt.dst_id ELSE NULL::integer END;


ALTER TABLE public.v_security_offenders_bytype OWNER TO eris;

--
-- Name: vlan_assignment; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE vlan_assignment (
    assign_id bigint NOT NULL,
    device_id integer NOT NULL,
    vlan_id integer NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    assign_ts time without time zone DEFAULT now(),
    assign_user_id integer,
    assign_notes character varying(25),
    assign_type character varying(25) DEFAULT 'automatic'::character varying NOT NULL,
    immutable boolean DEFAULT false
);


ALTER TABLE public.vlan_assignment OWNER TO eris;

--
-- Name: COLUMN vlan_assignment.immutable; Type: COMMENT; Schema: public; Owner: eris
--

COMMENT ON COLUMN vlan_assignment.immutable IS 'Disallows Changing of VLANs by automated processes';


--
-- Name: vlan_assignment_assign_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE vlan_assignment_assign_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vlan_assignment_assign_id_seq OWNER TO eris;

--
-- Name: vlan_assignment_assign_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE vlan_assignment_assign_id_seq OWNED BY vlan_assignment.assign_id;


--
-- Name: vlan_discovered; Type: TABLE; Schema: public; Owner: eris; Tablespace: 
--

CREATE TABLE vlan_discovered (
    vlan_discovery_id bigint NOT NULL,
    device_id integer NOT NULL,
    vlan_id integer NOT NULL,
    first_ts timestamp without time zone DEFAULT now() NOT NULL,
    last_ts timestamp without time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    discovery_method character varying(25) DEFAULT 'unknown'::character varying NOT NULL
);


ALTER TABLE public.vlan_discovered OWNER TO eris;

--
-- Name: vlans_discovered_vlan_discovery_id_seq; Type: SEQUENCE; Schema: public; Owner: eris
--

CREATE SEQUENCE vlans_discovered_vlan_discovery_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vlans_discovered_vlan_discovery_id_seq OWNER TO eris;

--
-- Name: vlans_discovered_vlan_discovery_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: eris
--

ALTER SEQUENCE vlans_discovered_vlan_discovery_id_seq OWNED BY vlan_discovered.vlan_discovery_id;


--
-- Name: authen_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE authen_current ALTER COLUMN authen_id SET DEFAULT nextval('authen_current_authen_id_seq'::regclass);


--
-- Name: device_class_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE device_classes ALTER COLUMN device_class_id SET DEFAULT nextval('device_classes_device_class_id_seq'::regclass);


--
-- Name: device_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE device_discovery ALTER COLUMN device_id SET DEFAULT nextval('device_discovery_device_id_seq'::regclass);


--
-- Name: status_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE device_status ALTER COLUMN status_id SET DEFAULT nextval('device_status_status_id_seq'::regclass);


--
-- Name: mgt_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE dnsmgr_ip_mgt ALTER COLUMN mgt_id SET DEFAULT nextval('dnsmgr_ip_mgt_mgt_id_seq'::regclass);


--
-- Name: range_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE dnsmgr_ip_mgt_range ALTER COLUMN range_id SET DEFAULT nextval('dnsmgr_ip_mgt_range_range_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE dnsmgr_ip_mgt_records ALTER COLUMN id SET DEFAULT nextval('dnsmgr_ip_mgt_records_id_seq'::regclass);


--
-- Name: record_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE dnsmgr_records ALTER COLUMN record_id SET DEFAULT nextval('dnsmgr_records_record_id_seq'::regclass);


--
-- Name: update_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE dnsmgr_updates ALTER COLUMN update_id SET DEFAULT nextval('dnsmgr_updates_update_id_seq'::regclass);


--
-- Name: zone_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE dnsmgr_zones ALTER COLUMN zone_id SET DEFAULT nextval('dnsmgr_zones_zone_id_seq'::regclass);


--
-- Name: node_type_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE eris_node_types ALTER COLUMN node_type_id SET DEFAULT nextval('eris_node_types_node_type_id_seq'::regclass);


--
-- Name: ou_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE eris_ous ALTER COLUMN ou_id SET DEFAULT nextval('eris_ous_ou_id_seq'::regclass);


--
-- Name: role_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE eris_roles ALTER COLUMN role_id SET DEFAULT nextval('eris_roles_role_id_seq'::regclass);


--
-- Name: user_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE eris_users ALTER COLUMN user_id SET DEFAULT nextval('eris_users_user_id_seq'::regclass);


--
-- Name: uniq_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE ext_custodians ALTER COLUMN uniq_id SET DEFAULT nextval('ext_custodians_uniq_id_seq'::regclass);


--
-- Name: unique_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE ext_lab_pco ALTER COLUMN unique_id SET DEFAULT nextval('ext_lab_pco_unique_id_seq'::regclass);


--
-- Name: suffix; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE fake_mac_addr ALTER COLUMN suffix SET DEFAULT nextval('fake_mac_addr_suffix_seq'::regclass);


--
-- Name: inv_archive_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE inventory_archive ALTER COLUMN inv_archive_id SET DEFAULT nextval('inventory_archive_inv_archive_id_seq'::regclass);


--
-- Name: map_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE map_device_status ALTER COLUMN map_id SET DEFAULT nextval('map_device_status_map_id_seq'::regclass);


--
-- Name: notify_admin_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE notification_admins ALTER COLUMN notify_admin_id SET DEFAULT nextval('notification_admins_notify_admin_id_seq'::regclass);


--
-- Name: email_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE notification_email ALTER COLUMN email_id SET DEFAULT nextval('notification_email_email_id_seq'::regclass);


--
-- Name: file_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE notification_files ALTER COLUMN file_id SET DEFAULT nextval('notification_files_file_id_seq'::regclass);


--
-- Name: notification_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE notification_meta ALTER COLUMN notification_id SET DEFAULT nextval('notification_meta_notification_id_seq'::regclass);


--
-- Name: queue_no; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE notification_queue ALTER COLUMN queue_no SET DEFAULT nextval('notification_queue_queue_no_seq'::regclass);


--
-- Name: reg_app_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE regulatory_application ALTER COLUMN reg_app_id SET DEFAULT nextval('regulatory_application_reg_app_id_seq'::regclass);


--
-- Name: reg_map_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE regulatory_compliance ALTER COLUMN reg_map_id SET DEFAULT nextval('regulatory_compliance_reg_map_id_seq'::regclass);


--
-- Name: reg_log_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE regulatory_device_log ALTER COLUMN reg_log_id SET DEFAULT nextval('regulatory_device_log_reg_log_id_seq'::regclass);


--
-- Name: reg_exp_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE regulatory_exception_classes ALTER COLUMN reg_exp_id SET DEFAULT nextval('regulatory_exception_classes_reg_exp_id_seq'::regclass);


--
-- Name: regulation_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE regulatory_meta ALTER COLUMN regulation_id SET DEFAULT nextval('regulatory_meta_regulation_id_seq'::regclass);


--
-- Name: waiver_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE regulatory_waivers ALTER COLUMN waiver_id SET DEFAULT nextval('regulatory_waivers_waiver_id_seq'::regclass);


--
-- Name: meta_waiver_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE regulatory_waivers_meta ALTER COLUMN meta_waiver_id SET DEFAULT nextval('regulatory_waivers_meta_meta_waiver_id_seq'::regclass);


--
-- Name: evt_type_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE security_event_types ALTER COLUMN evt_type_id SET DEFAULT nextval('security_event_types_evt_type_id_seq'::regclass);


--
-- Name: evt_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE security_events ALTER COLUMN evt_id SET DEFAULT nextval('security_events_evt_id_seq'::regclass);


--
-- Name: sig_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE security_signatures ALTER COLUMN sig_id SET DEFAULT nextval('security_signatures_sig_id_seq'::regclass);


--
-- Name: svc_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE services ALTER COLUMN svc_id SET DEFAULT nextval('services_svc_id_seq'::regclass);


--
-- Name: sp_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE switch_ports ALTER COLUMN sp_id SET DEFAULT nextval('switch_ports_sp_id_seq'::regclass);


--
-- Name: vlan_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE switch_vlans ALTER COLUMN vlan_id SET DEFAULT nextval('switch_vlans_vlan_id_seq'::regclass);


--
-- Name: message_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE syslog_archive ALTER COLUMN message_id SET DEFAULT nextval('syslog_archive_message_id_seq'::regclass);


--
-- Name: assign_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE vlan_assignment ALTER COLUMN assign_id SET DEFAULT nextval('vlan_assignment_assign_id_seq'::regclass);


--
-- Name: vlan_discovery_id; Type: DEFAULT; Schema: public; Owner: eris
--

ALTER TABLE vlan_discovered ALTER COLUMN vlan_discovery_id SET DEFAULT nextval('vlans_discovered_vlan_discovery_id_seq'::regclass);


SET search_path = matviews, pg_catalog;

--
-- Name: matviews_pkey; Type: CONSTRAINT; Schema: matviews; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY matviews
    ADD CONSTRAINT matviews_pkey PRIMARY KEY (mv_name);


SET search_path = public, pg_catalog;

--
-- Name: device_classes_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY device_classes
    ADD CONSTRAINT device_classes_pkey PRIMARY KEY (device_class_id);


--
-- Name: device_details_pk; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY device_details
    ADD CONSTRAINT device_details_pk PRIMARY KEY (device_id);


--
-- Name: eris_node_types_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY eris_node_types
    ADD CONSTRAINT eris_node_types_pkey PRIMARY KEY (node_type_id);


--
-- Name: eris_ous_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY eris_ous
    ADD CONSTRAINT eris_ous_pkey PRIMARY KEY (ou_id);


--
-- Name: eris_users_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY eris_users
    ADD CONSTRAINT eris_users_pkey PRIMARY KEY (user_id);


--
-- Name: idx_devices_macs; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY device_discovery
    ADD CONSTRAINT idx_devices_macs UNIQUE (mac_addr);


--
-- Name: pk_authen_current; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY authen_current
    ADD CONSTRAINT pk_authen_current PRIMARY KEY (authen_id);


--
-- Name: pk_device_discovery; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY device_discovery
    ADD CONSTRAINT pk_device_discovery PRIMARY KEY (device_id);


--
-- Name: pk_device_parents; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY device_parents
    ADD CONSTRAINT pk_device_parents PRIMARY KEY (parent_id, child_id);


--
-- Name: pk_device_status; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY device_status
    ADD CONSTRAINT pk_device_status PRIMARY KEY (status_id);


--
-- Name: pk_dnsmgr_ip_mgt; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY dnsmgr_ip_mgt
    ADD CONSTRAINT pk_dnsmgr_ip_mgt PRIMARY KEY (mgt_id);


--
-- Name: pk_dnsmgr_ip_mgt_range; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY dnsmgr_ip_mgt_range
    ADD CONSTRAINT pk_dnsmgr_ip_mgt_range PRIMARY KEY (range_id);


--
-- Name: pk_dnsmgr_ip_mgt_records; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY dnsmgr_ip_mgt_records
    ADD CONSTRAINT pk_dnsmgr_ip_mgt_records PRIMARY KEY (id);


--
-- Name: pk_dnsmgr_updates; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY dnsmgr_updates
    ADD CONSTRAINT pk_dnsmgr_updates PRIMARY KEY (update_id);


--
-- Name: pk_dnsmgr_zone; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY dnsmgr_zones
    ADD CONSTRAINT pk_dnsmgr_zone PRIMARY KEY (zone_id);


--
-- Name: pk_dnsmrg_record; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY dnsmgr_records
    ADD CONSTRAINT pk_dnsmrg_record PRIMARY KEY (record_id);


--
-- Name: pk_eris_role_map; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY eris_role_map
    ADD CONSTRAINT pk_eris_role_map PRIMARY KEY (role_id, user_id);


--
-- Name: pk_eris_roles; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY eris_roles
    ADD CONSTRAINT pk_eris_roles PRIMARY KEY (role_id);


--
-- Name: pk_ext_custodians; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY ext_custodians
    ADD CONSTRAINT pk_ext_custodians PRIMARY KEY (uniq_id);


--
-- Name: pk_ext_property_book; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY ext_property_book
    ADD CONSTRAINT pk_ext_property_book PRIMARY KEY (property_tag);


--
-- Name: pk_ext_property_pco; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY ext_lab_pco
    ADD CONSTRAINT pk_ext_property_pco PRIMARY KEY (unique_id);


--
-- Name: pk_ext_surplus_sheets; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY ext_surplus_sheets
    ADD CONSTRAINT pk_ext_surplus_sheets PRIMARY KEY (property_tag);


--
-- Name: pk_fake_mac_addr; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY fake_mac_addr
    ADD CONSTRAINT pk_fake_mac_addr PRIMARY KEY (suffix);


--
-- Name: pk_inventory_archive; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY inventory_archive
    ADD CONSTRAINT pk_inventory_archive PRIMARY KEY (inv_archive_id);


--
-- Name: pk_map_device_status; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY map_device_status
    ADD CONSTRAINT pk_map_device_status PRIMARY KEY (map_id);


--
-- Name: pk_map_notification_email_rcpts; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY map_notification_email_rcpts
    ADD CONSTRAINT pk_map_notification_email_rcpts PRIMARY KEY (email_id, user_id);


--
-- Name: pk_notification_admins; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY notification_admins
    ADD CONSTRAINT pk_notification_admins PRIMARY KEY (notify_admin_id);


--
-- Name: pk_notification_email; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY notification_email
    ADD CONSTRAINT pk_notification_email PRIMARY KEY (email_id);


--
-- Name: pk_notification_file; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY notification_files
    ADD CONSTRAINT pk_notification_file PRIMARY KEY (file_id);


--
-- Name: pk_notification_meta_id; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY notification_meta
    ADD CONSTRAINT pk_notification_meta_id PRIMARY KEY (notification_id);


--
-- Name: pk_notification_queue; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY notification_queue
    ADD CONSTRAINT pk_notification_queue PRIMARY KEY (queue_no);


--
-- Name: pk_regulatory_application; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY regulatory_application
    ADD CONSTRAINT pk_regulatory_application PRIMARY KEY (reg_app_id);


--
-- Name: pk_regulatory_compliance; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY regulatory_compliance
    ADD CONSTRAINT pk_regulatory_compliance PRIMARY KEY (reg_map_id);


--
-- Name: pk_regulatory_exception_classes; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY regulatory_exception_classes
    ADD CONSTRAINT pk_regulatory_exception_classes PRIMARY KEY (reg_exp_id);


--
-- Name: pk_security_event_types; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY security_event_types
    ADD CONSTRAINT pk_security_event_types PRIMARY KEY (evt_type_id);


--
-- Name: pk_security_events; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY security_events
    ADD CONSTRAINT pk_security_events PRIMARY KEY (evt_id);


--
-- Name: pk_security_idx; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY services
    ADD CONSTRAINT pk_security_idx PRIMARY KEY (svc_id);


--
-- Name: pk_security_signatures; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY security_signatures
    ADD CONSTRAINT pk_security_signatures PRIMARY KEY (sig_id);


--
-- Name: pk_switch_vlans; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY switch_vlans
    ADD CONSTRAINT pk_switch_vlans PRIMARY KEY (vlan_id);


--
-- Name: pk_syslog_archive; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY syslog_archive
    ADD CONSTRAINT pk_syslog_archive PRIMARY KEY (message_id);


--
-- Name: pk_vlan_assignment; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY vlan_assignment
    ADD CONSTRAINT pk_vlan_assignment PRIMARY KEY (assign_id);


--
-- Name: pk_vlan_current; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY vlan_discovered
    ADD CONSTRAINT pk_vlan_current PRIMARY KEY (vlan_discovery_id);


--
-- Name: regulatory_device_log_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY regulatory_device_log
    ADD CONSTRAINT regulatory_device_log_pkey PRIMARY KEY (reg_log_id);


--
-- Name: regulatory_meta_name_key; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY regulatory_meta
    ADD CONSTRAINT regulatory_meta_name_key UNIQUE (name);


--
-- Name: regulatory_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY regulatory_meta
    ADD CONSTRAINT regulatory_meta_pkey PRIMARY KEY (regulation_id);


--
-- Name: regulatory_waivers_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY regulatory_waivers_meta
    ADD CONSTRAINT regulatory_waivers_meta_pkey PRIMARY KEY (meta_waiver_id);


--
-- Name: regulatory_waivers_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY regulatory_waivers
    ADD CONSTRAINT regulatory_waivers_pkey PRIMARY KEY (waiver_id);


--
-- Name: sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: switch_ports_pkey; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY switch_ports
    ADD CONSTRAINT switch_ports_pkey PRIMARY KEY (sp_id);


--
-- Name: uniq_dnsmgr_record; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY dnsmgr_records
    ADD CONSTRAINT uniq_dnsmgr_record UNIQUE (zone_id, name, class, type, opt, value);


--
-- Name: uniq_dnsmgr_zone; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY dnsmgr_zones
    ADD CONSTRAINT uniq_dnsmgr_zone UNIQUE (name);


--
-- Name: uniq_eris_role_name; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY eris_roles
    ADD CONSTRAINT uniq_eris_role_name UNIQUE (name);


--
-- Name: uniq_sec_evt_name; Type: CONSTRAINT; Schema: public; Owner: eris; Tablespace: 
--

ALTER TABLE ONLY security_event_types
    ADD CONSTRAINT uniq_sec_evt_name UNIQUE (name);


--
-- Name: cdx_security_signatures; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX cdx_security_signatures ON security_signatures USING btree (evt_type_id);

ALTER TABLE security_signatures CLUSTER ON cdx_security_signatures;


--
-- Name: fki_dnsmgr_ip_mgt_range; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX fki_dnsmgr_ip_mgt_range ON dnsmgr_ip_mgt_range USING btree (mgt_id);


--
-- Name: fki_inv_archive_user_id; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX fki_inv_archive_user_id ON inventory_archive USING btree (user_id);


--
-- Name: fki_mv_secoffsig30days_device; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX fki_mv_secoffsig30days_device ON mv_security_offenders_sig_30days USING btree (offender_id);


--
-- Name: fki_mv_secoffsig30days_sig; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX fki_mv_secoffsig30days_sig ON mv_security_offenders_sig_30days USING btree (sig_id);


--
-- Name: fki_notification_queue_orig_email; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX fki_notification_queue_orig_email ON notification_queue USING btree (orig_email_id);


--
-- Name: fki_notification_queue_summary_email; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX fki_notification_queue_summary_email ON notification_queue USING btree (summary_email_id);


--
-- Name: fki_switch_ports_vlan; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX fki_switch_ports_vlan ON switch_ports USING btree (vlan_id);


--
-- Name: idx_device_discovery_clientid; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_device_discovery_clientid ON device_discovery USING btree (clientid);


--
-- Name: idx_devices_ip_addr; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_devices_ip_addr ON device_discovery USING btree (ip_addr) WHERE (ip_addr IS NOT NULL);


--
-- Name: idx_eris_users; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_eris_users ON eris_users USING btree (username);

ALTER TABLE eris_users CLUSTER ON idx_eris_users;


--
-- Name: idx_eris_users_active; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_eris_users_active ON eris_users USING btree (is_active);


--
-- Name: idx_eris_users_unique_user; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE UNIQUE INDEX idx_eris_users_unique_user ON eris_users USING btree (username) WHERE (is_active IS TRUE);


--
-- Name: idx_inventory_archive_clientid; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_inventory_archive_clientid ON inventory_archive USING btree (clientid);


--
-- Name: idx_inventory_archive_device_id; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_inventory_archive_device_id ON inventory_archive USING btree (device_id) WHERE (device_id IS NOT NULL);


--
-- Name: idx_inventory_archive_ip; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_inventory_archive_ip ON inventory_archive USING btree (ip);


--
-- Name: idx_inventory_archive_mac_addr; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_inventory_archive_mac_addr ON inventory_archive USING btree (mac) WHERE (mac IS NOT NULL);


--
-- Name: idx_inventory_archive_ts; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_inventory_archive_ts ON inventory_archive USING btree (event_ts);


--
-- Name: idx_inventory_archive_username; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_inventory_archive_username ON inventory_archive USING btree (username);


--
-- Name: idx_map_device_status_archived; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_map_device_status_archived ON map_device_status USING btree (is_archived);


--
-- Name: idx_map_device_status_device_id; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_map_device_status_device_id ON map_device_status USING btree (device_id);


--
-- Name: idx_map_device_status_ts; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_map_device_status_ts ON map_device_status USING btree (mod_ts DESC);


--
-- Name: idx_notificaiton_queue_main; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_notificaiton_queue_main ON notification_queue USING btree (notification_id, first_ts);


--
-- Name: idx_notification_meta_enabled; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_notification_meta_enabled ON notification_meta USING btree (is_enabled DESC);


--
-- Name: idx_notification_queue_id; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_notification_queue_id ON notification_queue USING btree (notification_id);

ALTER TABLE notification_queue CLUSTER ON idx_notification_queue_id;


--
-- Name: idx_sec_evt_dst_id; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_sec_evt_dst_id ON security_events USING btree (dst_id);


--
-- Name: idx_sec_evt_sig; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_sec_evt_sig ON security_events USING btree (sig_id);


--
-- Name: idx_sec_evt_src_id; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_sec_evt_src_id ON security_events USING btree (src_id);


--
-- Name: idx_sec_evt_ts; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_sec_evt_ts ON security_events USING btree (event_ts);


--
-- Name: idx_secoffsig30days_violations; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_secoffsig30days_violations ON mv_security_offenders_sig_30days USING btree (violations);


--
-- Name: idx_security_event_types_level; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_security_event_types_level ON security_event_types USING btree (base_level);


--
-- Name: idx_switch_port_switch; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE INDEX idx_switch_port_switch ON switch_ports USING btree (switch_id);

ALTER TABLE switch_ports CLUSTER ON idx_switch_port_switch;


--
-- Name: idx_switch_ports_devices; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE UNIQUE INDEX idx_switch_ports_devices ON switch_ports USING btree (device_id);


--
-- Name: uniq_security_sigs_by_facility; Type: INDEX; Schema: public; Owner: eris; Tablespace: 
--

CREATE UNIQUE INDEX uniq_security_sigs_by_facility ON security_signatures USING btree (facility, native_sig_id);


--
-- Name: trig_device_details; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_device_details BEFORE INSERT OR UPDATE ON device_details FOR EACH ROW EXECUTE PROCEDURE tsp_device_details();


--
-- Name: trig_device_discovery_ip; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_device_discovery_ip BEFORE INSERT OR UPDATE ON device_discovery FOR EACH ROW EXECUTE PROCEDURE tsp_device_discovery_ip();


--
-- Name: trig_dnsmgr_ip_mgt_range; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_dnsmgr_ip_mgt_range BEFORE INSERT OR UPDATE ON dnsmgr_ip_mgt_range FOR EACH ROW EXECUTE PROCEDURE tsp_dnsmgr_ip_mgt_range();


--
-- Name: trig_dnsmgr_ip_mgt_records_after; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_dnsmgr_ip_mgt_records_after AFTER INSERT OR DELETE OR UPDATE ON dnsmgr_ip_mgt_records FOR EACH ROW EXECUTE PROCEDURE tsp_dnsmgr_ip_mgt_records_after();


--
-- Name: trig_dnsmgr_records_push; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_dnsmgr_records_push AFTER INSERT OR DELETE OR UPDATE ON dnsmgr_records FOR EACH ROW EXECUTE PROCEDURE tsp_dnsmgr_record_mgt_updater();


--
-- Name: trig_dnsmgr_updater; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_dnsmgr_updater AFTER INSERT OR DELETE OR UPDATE ON dnsmgr_records FOR EACH ROW EXECUTE PROCEDURE tsp_dnsmgr_records_updater();


--
-- Name: trig_ext_custodian_user_id; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_ext_custodian_user_id AFTER INSERT OR UPDATE ON ext_custodians FOR EACH ROW EXECUTE PROCEDURE tsp_ext_custodian_user_id();


--
-- Name: trig_ext_pb_user_id; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_ext_pb_user_id BEFORE INSERT OR UPDATE ON ext_property_book FOR EACH ROW EXECUTE PROCEDURE tsp_ext_pb_user_id();


--
-- Name: trig_inventory_archive; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_inventory_archive BEFORE INSERT ON inventory_archive FOR EACH ROW EXECUTE PROCEDURE plt_reverse_inventory();


--
-- Name: trig_map_device_status_insert; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_map_device_status_insert BEFORE INSERT ON map_device_status FOR EACH ROW EXECUTE PROCEDURE tsp_map_device_status_insert();


--
-- Name: trig_notificaiton_meta; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_notificaiton_meta BEFORE INSERT OR UPDATE ON notification_meta FOR EACH ROW EXECUTE PROCEDURE tsp_notification_meta();


--
-- Name: trig_notificaiton_queue; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_notificaiton_queue BEFORE INSERT ON notification_queue FOR EACH ROW EXECUTE PROCEDURE tsp_notification_queue();


--
-- Name: trig_notification_email; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_notification_email BEFORE INSERT ON notification_email FOR EACH ROW EXECUTE PROCEDURE tsp_notification_email();


--
-- Name: trig_security_events_insert; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_security_events_insert BEFORE INSERT ON security_events FOR EACH ROW EXECUTE PROCEDURE tsp_security_events();


--
-- Name: trig_switch_ports_check; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_switch_ports_check BEFORE INSERT OR UPDATE ON switch_ports FOR EACH ROW EXECUTE PROCEDURE tsp_switch_ports_check();


--
-- Name: trig_ts2_syslog_archive; Type: TRIGGER; Schema: public; Owner: eris
--

CREATE TRIGGER trig_ts2_syslog_archive BEFORE INSERT OR UPDATE ON syslog_archive FOR EACH ROW EXECUTE PROCEDURE tsp_ts2_syslog_archive();


--
-- Name: device_class_mapping_device_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY device_class_mapping
    ADD CONSTRAINT device_class_mapping_device_class_id_fkey FOREIGN KEY (device_class_id) REFERENCES device_classes(device_class_id) ON DELETE CASCADE;


--
-- Name: device_class_mapping_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY device_class_mapping
    ADD CONSTRAINT device_class_mapping_device_id_fkey FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: device_class_mapping_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY device_class_mapping
    ADD CONSTRAINT device_class_mapping_user_id_fkey FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE RESTRICT;


--
-- Name: device_waivers_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY device_waivers
    ADD CONSTRAINT device_waivers_device_id_fkey FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: device_waivers_waiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY device_waivers
    ADD CONSTRAINT device_waivers_waiver_id_fkey FOREIGN KEY (waiver_id) REFERENCES regulatory_waivers(waiver_id) ON DELETE CASCADE;


--
-- Name: fk_authen_current_device_id; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY authen_current
    ADD CONSTRAINT fk_authen_current_device_id FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: fk_authen_current_user_id; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY authen_current
    ADD CONSTRAINT fk_authen_current_user_id FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE RESTRICT;


--
-- Name: fk_device_details_discovery; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY device_details
    ADD CONSTRAINT fk_device_details_discovery FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: fk_device_details_mod_user; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY device_details
    ADD CONSTRAINT fk_device_details_mod_user FOREIGN KEY (mod_user_id) REFERENCES eris_users(user_id) ON DELETE RESTRICT;


--
-- Name: fk_device_details_pri_user; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY device_details
    ADD CONSTRAINT fk_device_details_pri_user FOREIGN KEY (primary_user_id) REFERENCES eris_users(user_id) ON DELETE SET NULL;


--
-- Name: fk_device_details_type; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY device_details
    ADD CONSTRAINT fk_device_details_type FOREIGN KEY (node_type_id) REFERENCES eris_node_types(node_type_id) ON DELETE SET NULL;


--
-- Name: fk_device_status_device; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY map_device_status
    ADD CONSTRAINT fk_device_status_device FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: fk_dnsmgr_ip_mgt_range; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY dnsmgr_ip_mgt_range
    ADD CONSTRAINT fk_dnsmgr_ip_mgt_range FOREIGN KEY (mgt_id) REFERENCES dnsmgr_ip_mgt(mgt_id) ON DELETE CASCADE;


--
-- Name: fk_dnsmgr_updates_zone; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY dnsmgr_updates
    ADD CONSTRAINT fk_dnsmgr_updates_zone FOREIGN KEY (zone_id) REFERENCES dnsmgr_zones(zone_id) ON DELETE SET NULL;


--
-- Name: fk_eris_role_map_role; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY eris_role_map
    ADD CONSTRAINT fk_eris_role_map_role FOREIGN KEY (role_id) REFERENCES eris_roles(role_id) ON DELETE CASCADE;


--
-- Name: fk_eris_role_map_user; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY eris_role_map
    ADD CONSTRAINT fk_eris_role_map_user FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE CASCADE;


--
-- Name: fk_ext_custodians_user; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY ext_custodians
    ADD CONSTRAINT fk_ext_custodians_user FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE CASCADE;


--
-- Name: fk_ext_property_book_device; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY ext_property_book
    ADD CONSTRAINT fk_ext_property_book_device FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE SET NULL;


--
-- Name: fk_ext_property_book_user; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY ext_property_book
    ADD CONSTRAINT fk_ext_property_book_user FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE SET NULL;


--
-- Name: fk_ext_property_pco; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY ext_lab_pco
    ADD CONSTRAINT fk_ext_property_pco FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE CASCADE;


--
-- Name: fk_inv_archive_user_id; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY inventory_archive
    ADD CONSTRAINT fk_inv_archive_user_id FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE SET NULL;


--
-- Name: fk_map_device_status_status; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY map_device_status
    ADD CONSTRAINT fk_map_device_status_status FOREIGN KEY (status_id) REFERENCES device_status(status_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: fk_map_email_rcpts_email; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY map_notification_email_rcpts
    ADD CONSTRAINT fk_map_email_rcpts_email FOREIGN KEY (email_id) REFERENCES notification_email(email_id) ON DELETE CASCADE;


--
-- Name: fk_map_email_rcpts_user; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY map_notification_email_rcpts
    ADD CONSTRAINT fk_map_email_rcpts_user FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE CASCADE;


--
-- Name: fk_mv_secoffsig30days_device; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY mv_security_offenders_sig_30days
    ADD CONSTRAINT fk_mv_secoffsig30days_device FOREIGN KEY (offender_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: fk_mv_secoffsig30days_sig; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY mv_security_offenders_sig_30days
    ADD CONSTRAINT fk_mv_secoffsig30days_sig FOREIGN KEY (sig_id) REFERENCES security_signatures(sig_id) ON DELETE CASCADE;


--
-- Name: fk_notificaiton_queue_summary_email; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_queue
    ADD CONSTRAINT fk_notificaiton_queue_summary_email FOREIGN KEY (summary_email_id) REFERENCES notification_email(email_id) ON DELETE SET NULL;


--
-- Name: fk_notification_admin_meta; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_admins
    ADD CONSTRAINT fk_notification_admin_meta FOREIGN KEY (notification_id) REFERENCES notification_meta(notification_id) ON DELETE CASCADE;


--
-- Name: fk_notification_admin_user_id; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_admins
    ADD CONSTRAINT fk_notification_admin_user_id FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE CASCADE;


--
-- Name: fk_notification_email_files; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_email
    ADD CONSTRAINT fk_notification_email_files FOREIGN KEY (file_id) REFERENCES notification_files(file_id) ON DELETE SET NULL;


--
-- Name: fk_notification_meta_evt_type_id; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_meta
    ADD CONSTRAINT fk_notification_meta_evt_type_id FOREIGN KEY (evt_type_id) REFERENCES security_event_types(evt_type_id) ON DELETE RESTRICT;


--
-- Name: fk_notification_meta_mod_user_id; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_meta
    ADD CONSTRAINT fk_notification_meta_mod_user_id FOREIGN KEY (mod_user_id) REFERENCES eris_users(user_id) ON DELETE SET NULL;


--
-- Name: fk_notification_queue_meta; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_queue
    ADD CONSTRAINT fk_notification_queue_meta FOREIGN KEY (notification_id) REFERENCES notification_meta(notification_id) ON DELETE CASCADE;


--
-- Name: fk_notification_queue_orig_email; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_queue
    ADD CONSTRAINT fk_notification_queue_orig_email FOREIGN KEY (orig_email_id) REFERENCES notification_email(email_id) ON DELETE SET NULL;


--
-- Name: fk_notification_queue_user; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_queue
    ADD CONSTRAINT fk_notification_queue_user FOREIGN KEY (to_user_id) REFERENCES eris_users(user_id) ON DELETE CASCADE;


--
-- Name: fk_regulatory_application_regulation; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_application
    ADD CONSTRAINT fk_regulatory_application_regulation FOREIGN KEY (regulation_id) REFERENCES regulatory_meta(regulation_id) ON DELETE CASCADE;


--
-- Name: fk_regulatory_application_type; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_application
    ADD CONSTRAINT fk_regulatory_application_type FOREIGN KEY (node_type_id) REFERENCES eris_node_types(node_type_id) ON DELETE CASCADE;


--
-- Name: fk_regulatory_compliance_reg; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_compliance
    ADD CONSTRAINT fk_regulatory_compliance_reg FOREIGN KEY (regulation_id) REFERENCES regulatory_meta(regulation_id) ON DELETE CASCADE;


--
-- Name: fk_regulatory_map_dev; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_compliance
    ADD CONSTRAINT fk_regulatory_map_dev FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: fk_sec_sig_evt_type_id; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY security_signatures
    ADD CONSTRAINT fk_sec_sig_evt_type_id FOREIGN KEY (evt_type_id) REFERENCES security_event_types(evt_type_id) ON DELETE SET NULL;


--
-- Name: fk_security_events_signature; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY security_events
    ADD CONSTRAINT fk_security_events_signature FOREIGN KEY (sig_id) REFERENCES security_signatures(sig_id) ON DELETE CASCADE;


--
-- Name: fk_services_device_id; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY services
    ADD CONSTRAINT fk_services_device_id FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: fk_switch_port_switch; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY switch_ports
    ADD CONSTRAINT fk_switch_port_switch FOREIGN KEY (switch_id) REFERENCES device_discovery(device_id) ON DELETE RESTRICT;


--
-- Name: fk_switch_ports_device; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY switch_ports
    ADD CONSTRAINT fk_switch_ports_device FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: fk_switch_ports_vlan; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY switch_ports
    ADD CONSTRAINT fk_switch_ports_vlan FOREIGN KEY (vlan_id) REFERENCES switch_vlans(vlan_id) ON DELETE SET NULL;


--
-- Name: fk_vlan_assignment_device; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY vlan_assignment
    ADD CONSTRAINT fk_vlan_assignment_device FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: fk_vlan_assignment_user; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY vlan_assignment
    ADD CONSTRAINT fk_vlan_assignment_user FOREIGN KEY (assign_user_id) REFERENCES eris_users(user_id) ON DELETE RESTRICT;


--
-- Name: fk_vlan_assignment_vlan; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY vlan_assignment
    ADD CONSTRAINT fk_vlan_assignment_vlan FOREIGN KEY (vlan_id) REFERENCES switch_vlans(vlan_id) ON DELETE SET NULL;


--
-- Name: fk_vlan_current_device; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY vlan_discovered
    ADD CONSTRAINT fk_vlan_current_device FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: fk_vlan_current_vlan; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY vlan_discovered
    ADD CONSTRAINT fk_vlan_current_vlan FOREIGN KEY (vlan_id) REFERENCES switch_vlans(vlan_id) ON DELETE RESTRICT;


--
-- Name: fki_dnsmgr_records_zone; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY dnsmgr_records
    ADD CONSTRAINT fki_dnsmgr_records_zone FOREIGN KEY (zone_id) REFERENCES dnsmgr_zones(zone_id);


--
-- Name: idx_notification_email_meta; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_email
    ADD CONSTRAINT idx_notification_email_meta FOREIGN KEY (notification_id) REFERENCES notification_meta(notification_id) ON DELETE SET NULL;


--
-- Name: idx_notification_email_user; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY notification_email
    ADD CONSTRAINT idx_notification_email_user FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE CASCADE;


--
-- Name: regulatory_device_log_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_device_log
    ADD CONSTRAINT regulatory_device_log_device_id_fkey FOREIGN KEY (device_id) REFERENCES device_discovery(device_id) ON DELETE CASCADE;


--
-- Name: regulatory_device_log_regulation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_device_log
    ADD CONSTRAINT regulatory_device_log_regulation_id_fkey FOREIGN KEY (regulation_id) REFERENCES regulatory_meta(regulation_id) ON DELETE CASCADE;


--
-- Name: regulatory_device_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_device_log
    ADD CONSTRAINT regulatory_device_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE RESTRICT;


--
-- Name: regulatory_exception_classes_device_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_exception_classes
    ADD CONSTRAINT regulatory_exception_classes_device_class_id_fkey FOREIGN KEY (device_class_id) REFERENCES device_classes(device_class_id) ON DELETE RESTRICT;


--
-- Name: regulatory_exception_classes_regulation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_exception_classes
    ADD CONSTRAINT regulatory_exception_classes_regulation_id_fkey FOREIGN KEY (regulation_id) REFERENCES regulatory_meta(regulation_id) ON DELETE RESTRICT;


--
-- Name: regulatory_waiver_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_waiver_log
    ADD CONSTRAINT regulatory_waiver_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES eris_users(user_id) ON DELETE RESTRICT;


--
-- Name: regulatory_waiver_log_waiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_waiver_log
    ADD CONSTRAINT regulatory_waiver_log_waiver_id_fkey FOREIGN KEY (waiver_id) REFERENCES regulatory_waivers(waiver_id) ON DELETE CASCADE;


--
-- Name: regulatory_waivers_meta_authoritative_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_waivers_meta
    ADD CONSTRAINT regulatory_waivers_meta_authoritative_user_id_fkey FOREIGN KEY (authoritative_user_id) REFERENCES eris_users(user_id) ON DELETE RESTRICT;


--
-- Name: regulatory_waivers_meta_exception_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_waivers_meta
    ADD CONSTRAINT regulatory_waivers_meta_exception_class_id_fkey FOREIGN KEY (exception_class_id) REFERENCES device_classes(device_class_id) ON DELETE CASCADE;


--
-- Name: regulatory_waivers_meta_regulation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_waivers_meta
    ADD CONSTRAINT regulatory_waivers_meta_regulation_id_fkey FOREIGN KEY (regulation_id) REFERENCES regulatory_meta(regulation_id) ON DELETE CASCADE;


--
-- Name: regulatory_waivers_meta_waiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY regulatory_waivers
    ADD CONSTRAINT regulatory_waivers_meta_waiver_id_fkey FOREIGN KEY (meta_waiver_id) REFERENCES regulatory_waivers_meta(meta_waiver_id) ON DELETE RESTRICT;


--
-- Name: security_events_dst_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY security_events
    ADD CONSTRAINT security_events_dst_user_id_fkey FOREIGN KEY (dst_user_id) REFERENCES eris_users(user_id) ON DELETE SET NULL;


--
-- Name: security_events_src_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: eris
--

ALTER TABLE ONLY security_events
    ADD CONSTRAINT security_events_src_user_id_fkey FOREIGN KEY (src_user_id) REFERENCES eris_users(user_id) ON DELETE SET NULL;


--
-- Name: matviews; Type: ACL; Schema: -; Owner: eris
--

REVOKE ALL ON SCHEMA matviews FROM PUBLIC;
REVOKE ALL ON SCHEMA matviews FROM eris;
GRANT ALL ON SCHEMA matviews TO eris;
GRANT USAGE ON SCHEMA matviews TO PUBLIC;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO readonly;


--
-- Name: sp_lookup_device_id(character varying); Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON FUNCTION sp_lookup_device_id(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION sp_lookup_device_id(character varying) FROM eris;
GRANT ALL ON FUNCTION sp_lookup_device_id(character varying) TO eris;
GRANT ALL ON FUNCTION sp_lookup_device_id(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION sp_lookup_device_id(character varying) TO readonly;


--
-- Name: security_event_types; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE security_event_types FROM PUBLIC;
REVOKE ALL ON TABLE security_event_types FROM eris;
GRANT ALL ON TABLE security_event_types TO eris;
GRANT SELECT,REFERENCES ON TABLE security_event_types TO readonly;


--
-- Name: security_events; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE security_events FROM PUBLIC;
REVOKE ALL ON TABLE security_events FROM eris;
GRANT ALL ON TABLE security_events TO eris;
GRANT SELECT,REFERENCES ON TABLE security_events TO readonly;


--
-- Name: security_signatures; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE security_signatures FROM PUBLIC;
REVOKE ALL ON TABLE security_signatures FROM eris;
GRANT ALL ON TABLE security_signatures TO eris;
GRANT SELECT,REFERENCES ON TABLE security_signatures TO readonly;


SET search_path = matviews, pg_catalog;

--
-- Name: v_security_events_7days; Type: ACL; Schema: matviews; Owner: pg_admin
--

REVOKE ALL ON TABLE v_security_events_7days FROM PUBLIC;
REVOKE ALL ON TABLE v_security_events_7days FROM pg_admin;
GRANT ALL ON TABLE v_security_events_7days TO pg_admin;
GRANT SELECT ON TABLE v_security_events_7days TO PUBLIC;


--
-- Name: v_security_offenders_sig_30days; Type: ACL; Schema: matviews; Owner: eris
--

REVOKE ALL ON TABLE v_security_offenders_sig_30days FROM PUBLIC;
REVOKE ALL ON TABLE v_security_offenders_sig_30days FROM eris;
GRANT ALL ON TABLE v_security_offenders_sig_30days TO eris;
GRANT SELECT ON TABLE v_security_offenders_sig_30days TO PUBLIC;


SET search_path = public, pg_catalog;

--
-- Name: authen_current; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE authen_current FROM PUBLIC;
REVOKE ALL ON TABLE authen_current FROM eris;
GRANT ALL ON TABLE authen_current TO eris;
GRANT SELECT,REFERENCES ON TABLE authen_current TO readonly;


--
-- Name: device_class_mapping; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE device_class_mapping FROM PUBLIC;
REVOKE ALL ON TABLE device_class_mapping FROM eris;
GRANT ALL ON TABLE device_class_mapping TO eris;
GRANT SELECT,REFERENCES ON TABLE device_class_mapping TO readonly;


--
-- Name: device_classes; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE device_classes FROM PUBLIC;
REVOKE ALL ON TABLE device_classes FROM eris;
GRANT ALL ON TABLE device_classes TO eris;
GRANT SELECT,REFERENCES ON TABLE device_classes TO readonly;


--
-- Name: device_details; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE device_details FROM PUBLIC;
REVOKE ALL ON TABLE device_details FROM eris;
GRANT ALL ON TABLE device_details TO eris;
GRANT SELECT,REFERENCES ON TABLE device_details TO readonly;


--
-- Name: device_discovery; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE device_discovery FROM PUBLIC;
REVOKE ALL ON TABLE device_discovery FROM eris;
GRANT ALL ON TABLE device_discovery TO eris;
GRANT SELECT,REFERENCES ON TABLE device_discovery TO readonly;


--
-- Name: device_waivers; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE device_waivers FROM PUBLIC;
REVOKE ALL ON TABLE device_waivers FROM eris;
GRANT ALL ON TABLE device_waivers TO eris;
GRANT SELECT,REFERENCES ON TABLE device_waivers TO readonly;


--
-- Name: dnsmgr_ip_mgt; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE dnsmgr_ip_mgt FROM PUBLIC;
REVOKE ALL ON TABLE dnsmgr_ip_mgt FROM eris;
GRANT ALL ON TABLE dnsmgr_ip_mgt TO eris;
GRANT ALL ON TABLE dnsmgr_ip_mgt TO dnsmgr;


--
-- Name: dnsmgr_ip_mgt_range; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE dnsmgr_ip_mgt_range FROM PUBLIC;
REVOKE ALL ON TABLE dnsmgr_ip_mgt_range FROM eris;
GRANT ALL ON TABLE dnsmgr_ip_mgt_range TO eris;
GRANT ALL ON TABLE dnsmgr_ip_mgt_range TO dnsmgr;


--
-- Name: dnsmgr_ip_mgt_records; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE dnsmgr_ip_mgt_records FROM PUBLIC;
REVOKE ALL ON TABLE dnsmgr_ip_mgt_records FROM eris;
GRANT ALL ON TABLE dnsmgr_ip_mgt_records TO eris;


--
-- Name: dnsmgr_records; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE dnsmgr_records FROM PUBLIC;
REVOKE ALL ON TABLE dnsmgr_records FROM eris;
GRANT ALL ON TABLE dnsmgr_records TO eris;
GRANT ALL ON TABLE dnsmgr_records TO dnsmgr;
GRANT SELECT ON TABLE dnsmgr_records TO readonly;


--
-- Name: dnsmgr_records_record_id_seq; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON SEQUENCE dnsmgr_records_record_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE dnsmgr_records_record_id_seq FROM eris;
GRANT ALL ON SEQUENCE dnsmgr_records_record_id_seq TO eris;
GRANT USAGE ON SEQUENCE dnsmgr_records_record_id_seq TO dnsmgr;


--
-- Name: dnsmgr_updates; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE dnsmgr_updates FROM PUBLIC;
REVOKE ALL ON TABLE dnsmgr_updates FROM eris;
GRANT ALL ON TABLE dnsmgr_updates TO eris;
GRANT SELECT ON TABLE dnsmgr_updates TO readonly;
GRANT ALL ON TABLE dnsmgr_updates TO dnsmgr;


--
-- Name: dnsmgr_zones; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE dnsmgr_zones FROM PUBLIC;
REVOKE ALL ON TABLE dnsmgr_zones FROM eris;
GRANT ALL ON TABLE dnsmgr_zones TO eris;
GRANT ALL ON TABLE dnsmgr_zones TO dnsmgr;
GRANT SELECT ON TABLE dnsmgr_zones TO readonly;


--
-- Name: dnsmgr_zones_zone_id_seq; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON SEQUENCE dnsmgr_zones_zone_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE dnsmgr_zones_zone_id_seq FROM eris;
GRANT ALL ON SEQUENCE dnsmgr_zones_zone_id_seq TO eris;
GRANT USAGE ON SEQUENCE dnsmgr_zones_zone_id_seq TO dnsmgr;


--
-- Name: eris_node_types; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE eris_node_types FROM PUBLIC;
REVOKE ALL ON TABLE eris_node_types FROM eris;
GRANT ALL ON TABLE eris_node_types TO eris;
GRANT SELECT,REFERENCES ON TABLE eris_node_types TO readonly;


--
-- Name: eris_ous; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE eris_ous FROM PUBLIC;
REVOKE ALL ON TABLE eris_ous FROM eris;
GRANT ALL ON TABLE eris_ous TO eris;
GRANT SELECT,REFERENCES ON TABLE eris_ous TO readonly;


--
-- Name: eris_role_map; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE eris_role_map FROM PUBLIC;
REVOKE ALL ON TABLE eris_role_map FROM eris;
GRANT ALL ON TABLE eris_role_map TO eris;
GRANT SELECT ON TABLE eris_role_map TO readonly;


--
-- Name: eris_roles; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE eris_roles FROM PUBLIC;
REVOKE ALL ON TABLE eris_roles FROM eris;
GRANT ALL ON TABLE eris_roles TO eris;
GRANT SELECT ON TABLE eris_roles TO readonly;


--
-- Name: eris_users; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE eris_users FROM PUBLIC;
REVOKE ALL ON TABLE eris_users FROM eris;
GRANT ALL ON TABLE eris_users TO eris;
GRANT SELECT,REFERENCES ON TABLE eris_users TO readonly;


--
-- Name: ext_custodians; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE ext_custodians FROM PUBLIC;
REVOKE ALL ON TABLE ext_custodians FROM eris;
GRANT ALL ON TABLE ext_custodians TO eris;
GRANT SELECT ON TABLE ext_custodians TO readonly;


--
-- Name: ext_lab_pco; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE ext_lab_pco FROM PUBLIC;
REVOKE ALL ON TABLE ext_lab_pco FROM eris;
GRANT ALL ON TABLE ext_lab_pco TO eris;
GRANT SELECT ON TABLE ext_lab_pco TO readonly;


--
-- Name: ext_property_book; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE ext_property_book FROM PUBLIC;
REVOKE ALL ON TABLE ext_property_book FROM eris;
GRANT ALL ON TABLE ext_property_book TO eris;
GRANT SELECT ON TABLE ext_property_book TO readonly;


--
-- Name: ext_surplus_sheets; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE ext_surplus_sheets FROM PUBLIC;
REVOKE ALL ON TABLE ext_surplus_sheets FROM eris;
GRANT ALL ON TABLE ext_surplus_sheets TO eris;
GRANT SELECT ON TABLE ext_surplus_sheets TO readonly;


--
-- Name: fake_mac_addr; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE fake_mac_addr FROM PUBLIC;
REVOKE ALL ON TABLE fake_mac_addr FROM eris;
GRANT ALL ON TABLE fake_mac_addr TO eris;
GRANT SELECT ON TABLE fake_mac_addr TO readonly;


--
-- Name: inventory_archive; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE inventory_archive FROM PUBLIC;
REVOKE ALL ON TABLE inventory_archive FROM eris;
GRANT ALL ON TABLE inventory_archive TO eris;
GRANT SELECT,REFERENCES ON TABLE inventory_archive TO readonly;


--
-- Name: mv_security_offenders_sig_30days; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE mv_security_offenders_sig_30days FROM PUBLIC;
REVOKE ALL ON TABLE mv_security_offenders_sig_30days FROM eris;
GRANT ALL ON TABLE mv_security_offenders_sig_30days TO eris;
GRANT SELECT ON TABLE mv_security_offenders_sig_30days TO PUBLIC;


--
-- Name: notification_admins; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE notification_admins FROM PUBLIC;
REVOKE ALL ON TABLE notification_admins FROM eris;
GRANT ALL ON TABLE notification_admins TO eris;
GRANT SELECT,REFERENCES ON TABLE notification_admins TO readonly;


--
-- Name: notification_meta; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE notification_meta FROM PUBLIC;
REVOKE ALL ON TABLE notification_meta FROM eris;
GRANT ALL ON TABLE notification_meta TO eris;
GRANT SELECT,REFERENCES ON TABLE notification_meta TO readonly;


--
-- Name: notification_queue; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE notification_queue FROM PUBLIC;
REVOKE ALL ON TABLE notification_queue FROM eris;
GRANT ALL ON TABLE notification_queue TO eris;
GRANT SELECT,REFERENCES ON TABLE notification_queue TO readonly;


--
-- Name: regulatory_application; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE regulatory_application FROM PUBLIC;
REVOKE ALL ON TABLE regulatory_application FROM eris;
GRANT ALL ON TABLE regulatory_application TO eris;
GRANT SELECT,REFERENCES ON TABLE regulatory_application TO readonly;


--
-- Name: regulatory_compliance; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE regulatory_compliance FROM PUBLIC;
REVOKE ALL ON TABLE regulatory_compliance FROM eris;
GRANT ALL ON TABLE regulatory_compliance TO eris;
GRANT SELECT,REFERENCES ON TABLE regulatory_compliance TO readonly;


--
-- Name: regulatory_device_log; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE regulatory_device_log FROM PUBLIC;
REVOKE ALL ON TABLE regulatory_device_log FROM eris;
GRANT ALL ON TABLE regulatory_device_log TO eris;
GRANT SELECT,REFERENCES ON TABLE regulatory_device_log TO readonly;


--
-- Name: regulatory_exception_classes; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE regulatory_exception_classes FROM PUBLIC;
REVOKE ALL ON TABLE regulatory_exception_classes FROM eris;
GRANT ALL ON TABLE regulatory_exception_classes TO eris;
GRANT SELECT,REFERENCES ON TABLE regulatory_exception_classes TO readonly;


--
-- Name: regulatory_meta; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE regulatory_meta FROM PUBLIC;
REVOKE ALL ON TABLE regulatory_meta FROM eris;
GRANT ALL ON TABLE regulatory_meta TO eris;
GRANT SELECT,REFERENCES ON TABLE regulatory_meta TO readonly;


--
-- Name: regulatory_waiver_log; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE regulatory_waiver_log FROM PUBLIC;
REVOKE ALL ON TABLE regulatory_waiver_log FROM eris;
GRANT ALL ON TABLE regulatory_waiver_log TO eris;
GRANT SELECT,REFERENCES ON TABLE regulatory_waiver_log TO readonly;


--
-- Name: regulatory_waivers; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE regulatory_waivers FROM PUBLIC;
REVOKE ALL ON TABLE regulatory_waivers FROM eris;
GRANT ALL ON TABLE regulatory_waivers TO eris;
GRANT SELECT,REFERENCES ON TABLE regulatory_waivers TO readonly;


--
-- Name: regulatory_waivers_meta; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE regulatory_waivers_meta FROM PUBLIC;
REVOKE ALL ON TABLE regulatory_waivers_meta FROM eris;
GRANT ALL ON TABLE regulatory_waivers_meta TO eris;
GRANT SELECT,REFERENCES ON TABLE regulatory_waivers_meta TO readonly;


--
-- Name: services; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE services FROM PUBLIC;
REVOKE ALL ON TABLE services FROM eris;
GRANT ALL ON TABLE services TO eris;
GRANT SELECT,REFERENCES ON TABLE services TO readonly;


--
-- Name: sessions; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE sessions FROM PUBLIC;
REVOKE ALL ON TABLE sessions FROM eris;
GRANT ALL ON TABLE sessions TO eris;
GRANT SELECT,REFERENCES ON TABLE sessions TO readonly;


--
-- Name: switch_ports; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE switch_ports FROM PUBLIC;
REVOKE ALL ON TABLE switch_ports FROM eris;
GRANT ALL ON TABLE switch_ports TO eris;
GRANT SELECT,REFERENCES ON TABLE switch_ports TO readonly;


--
-- Name: switch_vlans; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE switch_vlans FROM PUBLIC;
REVOKE ALL ON TABLE switch_vlans FROM eris;
GRANT ALL ON TABLE switch_vlans TO eris;
GRANT SELECT,REFERENCES ON TABLE switch_vlans TO readonly;


--
-- Name: syslog_archive; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE syslog_archive FROM PUBLIC;
REVOKE ALL ON TABLE syslog_archive FROM eris;
GRANT ALL ON TABLE syslog_archive TO eris;
GRANT SELECT ON TABLE syslog_archive TO readonly;


--
-- Name: v_admin_index_usage; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE v_admin_index_usage FROM PUBLIC;
REVOKE ALL ON TABLE v_admin_index_usage FROM eris;
GRANT ALL ON TABLE v_admin_index_usage TO eris;
GRANT SELECT,REFERENCES ON TABLE v_admin_index_usage TO readonly;


--
-- Name: v_daily_authentication; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE v_daily_authentication FROM PUBLIC;
REVOKE ALL ON TABLE v_daily_authentication FROM eris;
GRANT ALL ON TABLE v_daily_authentication TO eris;
GRANT SELECT,REFERENCES ON TABLE v_daily_authentication TO readonly;


--
-- Name: v_device_overview; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE v_device_overview FROM PUBLIC;
REVOKE ALL ON TABLE v_device_overview FROM eris;
GRANT ALL ON TABLE v_device_overview TO eris;
GRANT SELECT,REFERENCES ON TABLE v_device_overview TO readonly;


--
-- Name: v_history_auth; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE v_history_auth FROM PUBLIC;
REVOKE ALL ON TABLE v_history_auth FROM eris;
GRANT ALL ON TABLE v_history_auth TO eris;
GRANT SELECT,REFERENCES ON TABLE v_history_auth TO readonly;


--
-- Name: v_history_node; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE v_history_node FROM PUBLIC;
REVOKE ALL ON TABLE v_history_node FROM eris;
GRANT ALL ON TABLE v_history_node TO eris;
GRANT SELECT,REFERENCES ON TABLE v_history_node TO readonly;


--
-- Name: v_security_offenders_bytype; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE v_security_offenders_bytype FROM PUBLIC;
REVOKE ALL ON TABLE v_security_offenders_bytype FROM eris;
GRANT ALL ON TABLE v_security_offenders_bytype TO eris;
GRANT SELECT ON TABLE v_security_offenders_bytype TO readonly;


--
-- Name: vlan_assignment; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE vlan_assignment FROM PUBLIC;
REVOKE ALL ON TABLE vlan_assignment FROM eris;
GRANT ALL ON TABLE vlan_assignment TO eris;
GRANT SELECT,REFERENCES ON TABLE vlan_assignment TO readonly;


--
-- Name: vlan_discovered; Type: ACL; Schema: public; Owner: eris
--

REVOKE ALL ON TABLE vlan_discovered FROM PUBLIC;
REVOKE ALL ON TABLE vlan_discovered FROM eris;
GRANT ALL ON TABLE vlan_discovered TO eris;
GRANT SELECT,REFERENCES ON TABLE vlan_discovered TO readonly;


--
-- PostgreSQL database dump complete
--

INSERT INTO eris_users ( username, display_name, first_name, last_name )
	values ( 'eris_admin', 'eris administrator', 'eris', 'administrator' );

