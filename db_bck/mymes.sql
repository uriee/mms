--
-- PostgreSQL database dump
--

-- Dumped from database version 10.10 (Ubuntu 10.10-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 11.3

-- Started on 2019-11-07 08:21:46

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 16388)
-- Name: mymes; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA mymes;


--
-- TOC entry 4 (class 2615 OID 16917)
-- Name: test; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA test;


--
-- TOC entry 1061 (class 1247 OID 26214)
-- Name: approval; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.approval AS ENUM (
    'Pending approval',
    'Approved',
    'Rejected'
);


--
-- TOC entry 1181 (class 1247 OID 27504)
-- Name: condition_t; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.condition_t AS ENUM (
    'EQ',
    'GT',
    'LT',
    'EGT',
    'ELS',
    'BETWEEN',
    'FUNC_P1',
    'FUNC_P2',
    'FUNC_P3'
);


--
-- TOC entry 1058 (class 1247 OID 26207)
-- Name: delivery_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.delivery_method AS ENUM (
    'Integral email',
    'External email',
    'Both'
);


--
-- TOC entry 883 (class 1247 OID 17071)
-- Name: equipment_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.equipment_type AS ENUM (
    'Machine',
    'Tool',
    'Machine accessory'
);


--
-- TOC entry 820 (class 1247 OID 17088)
-- Name: malfunction_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.malfunction_status AS ENUM (
    'Open',
    'Under Treatment',
    'Closed'
);


--
-- TOC entry 1068 (class 1247 OID 26260)
-- Name: manager_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.manager_type AS ENUM (
    'None',
    'Manager',
    'Manager(HR)'
);


--
-- TOC entry 1055 (class 1247 OID 25592)
-- Name: notifications_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.notifications_type AS ENUM (
    'notification',
    'message',
    'event'
);


--
-- TOC entry 954 (class 1247 OID 16988)
-- Name: row_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.row_type AS ENUM (
    'employee',
    'machine',
    'equipment',
    'place',
    'resource_group',
    'part',
    'mnt_plan',
    'malfunction',
    'repair',
    'availability_profile',
    'dept',
    'action',
    'serial',
    'serial_status',
    'process',
    'part_status',
    'user',
    'fault',
    'fault_type',
    'fault_status',
    'position',
    'malf',
    'malf_type',
    'malf_status',
    'work_report',
    'identifier_links',
    'fix'
);


--
-- TOC entry 387 (class 1255 OID 27007)
-- Name: check_identifier_exists(text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_identifier_exists(serial_name text, act_name text, row_type text, iden text) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
	sid integer;
	lid integer;
	fail boolean;
BEGIN
	select i.id into sid
	from mymes.identifier i, mymes.serials s
	where i.parent_id = s.part_id
	and s.name = serial_name
	and i.name = iden;
	
	select l.identifier_id into lid
	from mymes.identifier_links l, mymes.serials s, mymes.actions a , mymes.work_report w
	where l.identifier_id = sid
	and w.id = l.parent_id
	and a.name = act_name
	and s.name = serial_name
	and w.serial_id = s.id
	and w.act_id = a.id;
	
 IF (lid > 0 and row_type = 'work_report') THEN
  RAISE EXCEPTION 'Identifier had been allready reported for this action';
  RETURN -1 ;
 END IF;	
 
 	select true into fail
		from mymes.serial_act sa,
			 mymes.serial_act sao,
			 mymes.serials s,
			 mymes.actions a
		where sa.serial_id = s.id
			and s.name = serial_name
			and sa.act_id = a.id
			and a.name = act_name
			and sao.serial_id = s.id
			and sao.serialize is true
			and sao.pos < sa.pos
			and not exists (
				select * from mymes.identifier_links il
					where il.serial_id = sao.serial_id
						and il.act_id = sao.act_id	
						and il.identifier_id = sid
			);
			
 IF (fail is true and row_type = 'work_report') THEN
  RAISE EXCEPTION 'There is a former action that was not reported for this identifier';
  RETURN -1 ;
 END IF;			
			
 IF (sid is null and iden > '' and row_type <> 'work_report') THEN
  RAISE EXCEPTION 'Identifier Do Not Exists';
  RETURN -1 ;
 END IF;

 RETURN sid ;
END ; 

$$;


--
-- TOC entry 388 (class 1255 OID 27005)
-- Name: check_serial_act(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_serial_act() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
    bal integer;
	qnt integer;
	current_pos integer;
	prev_pos integer;
	wo integer;
    done integer;
    prev_done integer;
	
BEGIN

 if NEW.resource_id = -1 then return NEW;
 end if;
 
 select balance, quant, pos, quant - balance into bal, qnt, current_pos, done
 from mymes.serial_act 
 where serial_id = NEW.serial_id
 and act_id = NEW.act_id;
 
 select max(pos) into prev_pos
 from mymes.serial_act 
 where serial_id = NEW.serial_id 
 and pos < current_pos;
 
 select quant - balance into prev_done
  from mymes.serial_act
  where serial_id = NEW.serial_id 
  and pos = prev_pos;
 
 
 IF (NEW.quant + done  > prev_done ) THEN
 RAISE EXCEPTION 'Insufficient Balance In Previous Action';
 RETURN NULL ;
 END IF; 

 /* Raise exeption if there is there is no sufficient Balance in the serial action
 	or the amount is less then zero and exceeds the amount that was previously reported */
  IF (bal < NEW.quant or (qnt - bal) < NEW.quant * -1 ) THEN
 RAISE EXCEPTION 'Insufficient Balance';
 RETURN NULL ;
 END IF; 
 
 RETURN NEW ;

END ; 

$$;


--
-- TOC entry 381 (class 1255 OID 26975)
-- Name: check_serial_act(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_serial_act(serial_name text, act_name text, pbal integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    bal integer;
	qnt integer;
	current_pos integer;
	prev_pos integer;
	wo integer;
    done integer;
    prev_done integer;

	
BEGIN

 IF (serial_name = '' or act_name = '' or pbal = 0) THEN
 RAISE EXCEPTION 'check_serial_act_balance - parameters error';
 RETURN 0 ;
 END IF; 

 select sa.balance, sa.quant, sa.pos, s.id, sa.quant - sa.balance into bal, qnt, current_pos, wo, done
 from mymes.serial_act as sa,mymes.serials as s, mymes.actions as a
 where s.name = serial_name
 and a.name = act_name
 and sa.serial_id = s.id
 and sa.act_id = a.id;
 
 select max(pos) into prev_pos
 from mymes.serial_act 
 where serial_id = wo 
 and pos < current_pos;
 
 select quant - balance into prev_done
  from mymes.serial_act
  where serial_id = wo 
  and pos = prev_pos;
 
 
 IF (pbal + done  > prev_done ) THEN
 RAISE EXCEPTION 'Insufficient Balance In Previous Action';
 RETURN 0 ;
 END IF; 

 /* Raise exeption if there is there is no sufficient Balance in the serial action
 	or the amount is less then zero and exceeds the amount that was previously reported */
  IF (bal < pbal or (qnt - bal) < pbal*-1 ) THEN
 RAISE EXCEPTION 'Insufficient Balance';
 RETURN 0 ;
 END IF; 
 
 RETURN bal ;
END ; 

$$;


--
-- TOC entry 374 (class 1255 OID 25469)
-- Name: check_serial_act_balance(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_serial_act_balance(serial_name text, act_name text, pbal integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    bal integer;
	
BEGIN

 IF (serial_name = '' or act_name = '' or pbal = 0) THEN
 RAISE EXCEPTION 'check_serial_act_balance - parameters error';
 RETURN 0 ;
 END IF; 

 select balance into bal
 from mymes.serial_act as sa,mymes.serials as s, mymes.actions as a
 where s.name = serial_name
 and a.name = act_name
 and sa.serial_id = s.id
 and sa.act_id = a.id;
 
  IF (bal < pbal) THEN
 RAISE EXCEPTION 'Insufficient Balance';
 RETURN 0 ;
 END IF; 
 
 RETURN bal ;
END ; 

$$;


--
-- TOC entry 378 (class 1255 OID 26514)
-- Name: clone_actions(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clone_actions(idp integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    new_id integer;
	
BEGIN

 insert into mymes.actions(row_type, tags, name, active,  quantitative, serialize)
 	select row_type, tags,name || '_clone',active, quantitative , serialize 
 	from mymes.actions where id = idp returning id into new_id;
 
 IF (idp < 1 or new_id < 1) THEN
 RAISE EXCEPTION 'clone_actions - parameters error';
 RETURN 0 ;
 END IF; 
 
 insert into mymes.actions_t(action_id,lang_id,description) select new_id,lang_id,description from mymes.actions_t where action_id = idp;
 insert into mymes.act_resources(type,act_id,resource_id,ord)
 	select 1,new_id,ar.resource_id,ar.ord
	from mymes.act_resources ar
	where ar.act_id = idp;
	
 RETURN new_id ;
END ; 

$$;


--
-- TOC entry 371 (class 1255 OID 26501)
-- Name: clone_equipments(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clone_equipments(e_param integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    new_id integer;
	
BEGIN

 insert into mymes.equipments(row_type, tags, name, dragable, active, availability_profile_id, mac_address, serial, equipment_type, calibrated, last_calibration)
 	select row_type, tags,name || '_clone',dragable, active, availability_profile_id, mac_address, serial, equipment_type, calibrated, last_calibration 
 	from mymes.equipments where id = e_param returning id into new_id;
 
 IF (e_param < 1 or new_id < 1) THEN
 RAISE EXCEPTION 'clone_equpment - parameters error';
 RETURN 0 ;
 END IF; 
 
 insert into mymes.equipments_t(equipment_id,lang_id,description) select new_id,lang_id,description from mymes.equipments_t where equipment_id = e_param;

 RETURN new_id ;
END ; 

$$;


--
-- TOC entry 380 (class 1255 OID 25443)
-- Name: clone_parts(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clone_parts(part_param integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    new_id integer;
	
BEGIN

 insert into mymes.part(row_type, tags, name, part_status_id, revision, serialize)
 	select row_type, tags, name, part_status_id, '0', serialize
	from mymes.part
	where id = part_param
	returning id into new_id;
 
 IF (part_param < 1 or new_id < 1) THEN
 RAISE EXCEPTION 'clone_parts - parameters error';
 RETURN 0 ;
 END IF; 
 
 insert into mymes.part_t(part_id,lang_id,description) select new_id,lang_id,description from mymes.part_t where part_id = part_param;
 insert into mymes.bom(parent_id,partname,coef) select new_id,partname,coef from mymes.bom where parent_id = part_param;
 insert into mymes.locations(part_id,act_id,partname,location,quant,x,y,z) select new_id,act_id,partname,location,quant,x,y,z from mymes.locations where part_id = part_param;
 
 RETURN new_id ;
END ; 

$$;


--
-- TOC entry 382 (class 1255 OID 26513)
-- Name: clone_process(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clone_process(idp integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    new_id integer;
	
BEGIN

 insert into mymes.process(row_type, tags, name, active, serial_report)
 	select row_type, tags,name || '_clone',active, serial_report 
 	from mymes.process where id = idp returning id into new_id;
 
 IF (idp < 1 or new_id < 1) THEN
 RAISE EXCEPTION 'clone_process - parameters error';
 RETURN 0 ;
 END IF; 
 
 insert into mymes.process_t(process_id,lang_id,description)
 	select new_id,lang_id,description
	from mymes.process_t
	where process_id = idp;
	
 insert into mymes.proc_act(process_id, act_id, pos, quantitative, serialize)
 	select new_id, act_id, pos, quantitative, serialize
	from mymes.proc_act
	where process_id = idp;
	
 insert into mymes.act_resources(type,act_id,resource_id,ord)
 	select 2,panew.id,ar.resource_id,ar.ord
	from mymes.proc_act paold, mymes.proc_act panew, mymes.act_resources ar
	where ar.act_id = paold.id
	and panew.process_id = new_id
	and paold.process_id = idp
	and panew.act_id = paold.act_id;
	
 RETURN new_id ;
END ; 

$$;


--
-- TOC entry 367 (class 1255 OID 26494)
-- Name: clone_resource_groups(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clone_resource_groups(rg_param integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    new_id integer;
	
BEGIN

 insert into mymes.resource_groups(row_type, tags, name, dragable, active, availability_profile_id,resource_ids)
 	select row_type, tags,name || '_clone',dragable, active, availability_profile_id, resource_ids
 	from mymes.resource_groups where id = rg_param returning id into new_id;
 
 IF (rg_param < 1 or new_id < 1) THEN
 RAISE EXCEPTION 'clone_parts - parameters error';
 RETURN 0 ;
 END IF; 
 
 insert into mymes.resource_groups_t(resource_group_id,lang_id,description) select new_id,lang_id,description from mymes.resource_groups_t where resource_group_id = rg_param;

 RETURN new_id ;
END ; 

$$;


--
-- TOC entry 389 (class 1255 OID 25365)
-- Name: cpy_acts_proc2ser(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cpy_acts_proc2ser(ser integer, proc text) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    proc_id integer := (
        select id
        from mymes.process
        where name = proc
    );
    ser_quant integer := (
        select quant
        from mymes.serials
        where id = ser
    );	
	batch_size integer := (
		select p.batch_size
		from mymes.part p,mymes.serials s
		where p.id = s.part_id
		and s.id = ser
	);
	
BEGIN
 
 IF (proc_id < 1 or ser < 1) THEN
 RAISE NOTICE 'cpy_acts_proc2ser - parameters error';
 RETURN 0 ;
 END IF; 

	insert into mymes.serial_act(serial_id, act_id, pos, quant, balance, quantitative, serialize, batch_size)
	select ser, act_id, pos, ser_quant, ser_quant,quantitative, serialize,
	CASE WHEN batch is true THEN batch_size ELSE null END
	from mymes.proc_act
	where process_id = proc_id;

	insert into mymes.act_resources(act_id,resource_id,type,ord)
	select sa.id,ar.resource_id,3,ar.ord
	from mymes.proc_act as pa, mymes.serial_act as sa, mymes.act_resources as ar
	where sa.act_id = pa.act_id 
	and process_id = proc_id
	and serial_id = ser
	and ar.type = 2
	and ar.act_id = pa.id;

 RETURN ser ;
END ; 

$$;


--
-- TOC entry 361 (class 1255 OID 25560)
-- Name: cpy_resource_timeoffs(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cpy_resource_timeoffs(timeoff_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    rid integer := (
        select resource_id
        from mymes.resource_timeoff
        where id = timeoff_id
    );
	
BEGIN
 
 IF(rid < 1 ) THEN
 RAISE NOTICE 'cpy_resource_timeoffs - parameters error';
 RETURN 0 ;
 END IF; 

 WITH RECURSIVE subres AS (
 SELECT
 id,
 resource_ids,
 name
 FROM
 mymes.resources
 WHERE
 id = rid
 UNION
 SELECT
 e.id,
 e.resource_ids,
 e.name
 FROM
  mymes.resources e
 INNER JOIN subres s ON  s.resource_ids @> ARRAY[e.id] 
)
insert into mymes.resource_timeoff(from_date,to_date,flag_o,parent_id,resource_id)
select tmp.from_date,tmp.to_date,tmp.flag_o,timeoff_id,subres.id
from (select from_date,to_date,flag_o from mymes.resource_timeoff where id = timeoff_id) as tmp,subres
where subres.id <> rid;

 RETURN rid ;
END ; 

$$;


--
-- TOC entry 354 (class 1255 OID 26403)
-- Name: cpy_resources_act2proc(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cpy_resources_act2proc(proc_id integer, act text) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    act_idd integer := (
        select id
        from mymes.actions
        where name = act
    );
	
BEGIN
 
 IF (act_idd < 1 or proc_id < 1) THEN
 RAISE NOTICE 'cpy_resources_act2proc - parameters error';
 RETURN 0 ;
 END IF; 

	insert into mymes.act_resources(act_id,resource_id,type,ord)
	select pa.id,ar.resource_id,2,ar.ord
	from mymes.actions as a, mymes.proc_act as pa, mymes.act_resources as ar
	where a.id = pa.act_id 
	and a.id = act_idd
	and pa.id = proc_id
	and ar.type = 1
	and ar.act_id = a.id;

 RETURN proc_id ;
END ; 

$$;


--
-- TOC entry 370 (class 1255 OID 26925)
-- Name: delete_identifier_link(integer[], text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_identifier_link(pids integer[], params text[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
	pid integer;
	is_parent integer;

BEGIN

  FOREACH pid IN ARRAY pids
  LOOP

	 select 1 into is_parent
	 from mymes.identifier
	 where parent_identifier_id = pid;
	 
	 IF (is_parent = 1) THEN 
	 RAISE EXCEPTION 'The Identifier has son Identifiers';
	 RETURN 0 ;
	 END IF;	 
	 
  END LOOP;
/*------------------------------------------------------------------------*/  

  FOREACH pid IN ARRAY pids
  LOOP

	 IF (params[1]::integer < 1 or params[2] = '' or pid < 1) THEN 
	 RAISE EXCEPTION 'delete_identifier - parameters error';
	 RETURN 0 ;
	 END IF;
	  

	 delete from mymes.identifier_links
	 where identifier_id = pid
	 and parent_id = params[1]::integer
	 and row_type = params[2]::row_type;

  END LOOP;

 RETURN 1 ;
END ; 

$$;


--
-- TOC entry 355 (class 1255 OID 25564)
-- Name: delete_resource_timeoffs(integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_resource_timeoffs(timeoff_id integer[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
    rid integer := (
        select resource_id
        from mymes.resource_timeoff
        where id = timeoff_id[1]
    );
    parents integer[] := (
        select array[parent_id]
        from mymes.resource_timeoff
        where array[id] <@ timeoff_id
    ); 	
	
BEGIN
RAISE NOTICE 'test % % %',timeoff_id,rid,parents ; 
 IF(rid < 1 ) THEN
 RAISE NOTICE 'delete_resource_timeoffs - parameters error';
 RETURN 0 ;
 END IF; 
RAISE NOTICE 'rid - %',rid; 
 WITH RECURSIVE subres AS (
 SELECT
 id,
 resource_ids,
 name
 FROM
 mymes.resources
 WHERE
 id = rid
 UNION
 SELECT
 e.id,
 e.resource_ids,
 e.name
 FROM
  mymes.resources e
 INNER JOIN subres s ON  s.resource_ids @> ARRAY[e.id] 
)
delete from mymes.resource_timeoff
where array[parent_id] <@ parents
and resource_id in (select id from subres);
/*and not exists(select 'x' from mymes.resources where array[mymes.resource_timeoff.resource_id] <@ resource_ids and mymes.resources.id not in (select id from subres));*/

return timeoff_id[1];
END;

$$;


--
-- TOC entry 394 (class 1255 OID 35711)
-- Name: event_trigger_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.event_trigger_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
	ret integer;
	trig record;
	queue text;
	sql_query text;
BEGIN
	FOR trig IN SELECT * FROM mymes.event_triggers WHERE table_id = TG_TABLE_NAME and active is true and del is true
    	LOOP
			EXECUTE trig.insert_sql into ret USING OLD;			
			RAISE log '1111 % - EROOR:%' , ret,trig.error;
			IF(ret = 1) THEN
				RAISE log '2222 % , %' , trig.queues,array_length(trig.queues, 1);
				IF(array_length(trig.queues, 1) > 0 ) then
					FOREACH queue IN ARRAY trig.queues
					   LOOP
					   	RAISE log '444 %' , queue;
						  insert into mymes.notifications(title,username,type) values(trig.message_text,queue,'notification');
					   END LOOP;
				END IF;
			RAISE EXCEPTION '%', trig.message_text; 
			RETURN NULL; 

			END IF;
   		END LOOP;

 RETURN OLD ;

END ; 

$$;


--
-- TOC entry 391 (class 1255 OID 35710)
-- Name: event_trigger_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.event_trigger_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
	ret integer;
	trig record;
	queue text;
BEGIN
	FOR trig IN SELECT * FROM mymes.event_triggers WHERE table_id = TG_TABLE_NAME and active is true 
    	LOOP
			EXECUTE trig.insert_sql into ret USING NEW;
			RAISE log '1111 % - EROOR:%' , ret,trig.error;
			IF(ret = 1) THEN
				RAISE log '2222 % , %' , trig.queues,array_length(trig.queues, 1);
				IF(array_length(trig.queues, 1) > 0 ) then
					FOREACH queue IN ARRAY trig.queues
					   LOOP
					   	RAISE log '444 %' , queue;
						  insert into mymes.notifications(title,username,type) values(trig.message_text,queue,'notification');
					   END LOOP;
				END IF;
			IF(trig.error is true) THEN
				RAISE EXCEPTION '%', trig.message_text; 
				RETURN NULL; 
			END IF;
			END IF;
   		END LOOP;

 RETURN NEW ;

END ; 

$$;


--
-- TOC entry 392 (class 1255 OID 35695)
-- Name: event_trigger_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.event_trigger_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
	ret integer;
	trig record;
	queue text;

BEGIN
	FOR trig IN SELECT * FROM mymes.event_triggers WHERE table_id = TG_TABLE_NAME and active is true 
    	LOOP
			EXECUTE trig.update_sql into ret USING NEW,OLD;
			RAISE log '1111 % - EROOR:%' , ret,trig.error;
			IF(ret = 1) THEN
				RAISE log '2222 % , %' , trig.queues,array_length(trig.queues, 1);
				IF(array_length(trig.queues, 1) > 0 ) then
					FOREACH queue IN ARRAY trig.queues
					   LOOP
					   	RAISE log '444 %' , queue;
						  insert into mymes.notifications(title,username,type) values(trig.message_text,queue,'notification');
					   END LOOP;
				END IF;
			IF(trig.error is true) THEN
				RAISE EXCEPTION '%', trig.message_text; 
				RETURN NULL; 
			END IF;
			END IF;
   		END LOOP;

 RETURN NEW ;

END ; 

$$;


--
-- TOC entry 379 (class 1255 OID 26973)
-- Name: fault_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fault_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
uname  character varying ;
begin

 select username into uname from users where id = NEW.sig_user ;
 
 insert into mymes.notifications(title,type,extra,username,schema)
	 select 'New Fault : ','event',NEW.name,usr.username,'fault'
	 from user_parent_users(uname) as usr;
 RETURN NULL;
end;
$$;


--
-- TOC entry 383 (class 1255 OID 26997)
-- Name: insert_identifier_link_post(integer, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_identifier_link_post(parent integer, row_type text, iden text) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
	sid integer;
	aid integer;
	iden_id integer;

BEGIN

	 IF (row_type = 'work_report') THEN
	 	select serial_id,act_id into sid,aid
		from mymes.work_report
		where id = parent;
	 END IF;
	 IF (row_type = 'fault') THEN
	 	select serial_id,0 into sid,aid
		from mymes.fault
		where id = parent;
	 END IF;	 
	 
	 select identifier.id into iden_id
	 from mymes.identifier , mymes.serials s
	 where parent_id = s.part_id
	 and s.id = sid
	 and identifier.name = iden;
	 
	 insert into mymes.identifier_links(identifier_id,parent_id,row_type,serial_id,act_id)
	 values(iden_id,parent,row_type::row_type,sid,aid)
	 on conflict do nothing;

 RETURN 1 ;
END ; 

$$;


--
-- TOC entry 377 (class 1255 OID 27444)
-- Name: insert_identifier_link_post(integer, text, text, integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_identifier_link_post(parent integer, row_type text, iden text, batch_array integer[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
	sid integer;
	aid integer;
	iden_id integer;

BEGIN

	 IF (row_type = 'work_report') THEN
	 	select serial_id,act_id into sid,aid
		from mymes.work_report
		where id = parent;
	 END IF;
	 IF (row_type = 'fault') THEN
	 	select serial_id,0 into sid,aid
		from mymes.fault
		where id = parent;
	 END IF;	 
	 
	 select identifier.id into iden_id
	 from mymes.identifier , mymes.serials s
	 where parent_id = s.part_id
	 and s.id = sid
	 and identifier.name = iden;
	 /*raise log 'post sid: %,iden_id: %, iden : %, parent: %', sid,iden_id,iden, parent;*/
	 IF (iden_id > 1 ) THEN
		 insert into mymes.identifier_links(identifier_id,parent_id,row_type,serial_id,act_id,batch_array)
		 values(iden_id,parent,row_type::row_type,sid,aid,batch_array);
		 /*on conflict do nothing;*/
	 END IF;	 

 RETURN 1 ;
END ; 

$$;


--
-- TOC entry 366 (class 1255 OID 26996)
-- Name: insert_identifier_link_pre(integer, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_identifier_link_pre(parent integer, row_type text, iden text) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
	sid integer;
	aid integer;
	exis integer;

BEGIN

	 IF (row_type = 'work_report') THEN
	 	select serial_id,act_id into sid,aid
		from mymes.work_report
		where id = parent;
	 END IF;
	 IF (row_type = 'fault') THEN
	 	select serial_id,act_id into sid,aid
		from mymes.fault
		where id = parent;
	 END IF;	 
	 
	 select i.id into exis
	 from mymes.identifier i , mymes.serials s
	 where i.parent_id = s.part_id
	 and s.id = sid
	 and i.name = iden;
	 /* raise log 'pre sid: %,iden_id: %, exis : %, parent: %', sid,exis,iden, parent;*/
	 IF (exis > 0 and sid > 0 ) THEN 
	 
	 insert into mymes.identifier_links(identifier_id,parent_id,row_type,serial_id,act_id)
	 values(exis,parent,row_type::row_type,sid,aid);
	 END IF;
	
	 IF (row_type = 'fault') then
	 return -1;
	 end if;
	 
 RETURN 1 ;
END ; 

$$;


--
-- TOC entry 362 (class 1255 OID 26484)
-- Name: mes_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mes_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  channel text := TG_ARGV[0];
begin
  PERFORM (
     with payload(id,name,title,icon,type,username) as
     (
       select NEW.id,NEW.name, NEW.title,NEW.icon ,NEW.type, NEW.username
     )
     select pg_notify(channel, row_to_json(payload)::text)
       from payload
  );
  RETURN NULL;
end;
$$;


--
-- TOC entry 369 (class 1255 OID 27402)
-- Name: post_delete_identifier(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.post_delete_identifier() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare

	
BEGIN

update mymes.identifier
set parent_identifier_id = null
where parent_identifier_id = OLD.id;
 
 RETURN OLD ;
END ; 

$$;


--
-- TOC entry 390 (class 1255 OID 27432)
-- Name: post_insert_identifier_link(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.post_insert_identifier_link() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
	skey integer;
	counter integer;
	NinB integer;
BEGIN
raise LOG '~~~~1 %', NEW.batch_array;
 IF (NEW.batch_array is null)  or NEW.row_type='fault' then return NEW; end if;

	 FOREACH NinB in array NEW.batch_array  LOOP
			raise LOG '~~~~ %', NinB;
			
			select s.id into skey
			from mymes.identifier s ,  mymes.identifier p
			where p.id = NEW.identifier_id
			and s.name = p.name ||'_' || NinB::text
			and s.parent_id = p.parent_id;
   
			if (skey is null) then
			insert into mymes.identifier(name, parent_id, created_at,mac_address, secondary, batch) 
				   select name ||'_' || NinB::text,
						  NEW.parent_id,
						  created_at,
						  mac_address,
						  secondary ||'_' || NinB::text,
						  name
				   from mymes.identifier where id = NEW.identifier_id			   
				   returning id into skey;
			end if;	
				
			insert into mymes.identifier_links(identifier_id,parent_id,row_type,serial_id,act_id,created_at,batch_array)
			values(skey,NEW.parent_id,NEW.row_type,NEW.serial_id,NEW.act_id,NEW.created_at,null);

	 END LOOP;
	
	 delete from mymes.identifier_links where identifier_id = NEW.identifier_id;
	 delete from mymes.identifier where id = NEW.identifier_id;	
	 
	
 
 RETURN null ;
END ; 

$$;


--
-- TOC entry 385 (class 1255 OID 27481)
-- Name: pre_delete_approved(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pre_delete_approved() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
    test boolean;
	
BEGIN

 IF to_jsonb(OLD) ? 'parent_id' THEN	
	 select approved into test
	 from mymes.sendable
	 where id = OLD.parent_id;
	 IF test is true THEN
		 RAISE EXCEPTION 'You are trying to delete a row that allready approved as accepted by the ERP';
		 RETURN NULL ;
	 END IF; 
	 RETURN OLD;
 END IF;
 
 IF  OLD.approved is true THEN
	 RAISE EXCEPTION 'You are trying to delete a row that allready approved as accepted by the ERP';
	 RETURN NULL ;
 END IF; 

 
 RETURN OLD ;
END ; 

$$;


--
-- TOC entry 363 (class 1255 OID 26910)
-- Name: pre_delete_identifier(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pre_delete_identifier() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
    test integer;
	
BEGIN

select identifier_id into test from mymes.identifier_links where identifier_id = OLD.id;
 
 IF (test > 0 ) THEN
/* RAISE EXCEPTION 'identifier has links';*/
 RETURN NULL ;
 END IF; 
 
 RETURN OLD ;
END ; 

$$;


--
-- TOC entry 359 (class 1255 OID 26902)
-- Name: pre_delete_sendable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pre_delete_sendable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
    test integer;
	
BEGIN

select identifier_id into test from mymes.identifier_links where parent_id = OLD.id;
 
 IF (test > 0 ) THEN
 RAISE EXCEPTION 'identifiable has identifiers links';
 RETURN NULL ;
 END IF; 
 
 RETURN OLD ;
END ; 

$$;


--
-- TOC entry 375 (class 1255 OID 26963)
-- Name: pre_insert_identifier(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pre_insert_identifier() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
    pid integer;
	test integer;
	
BEGIN
	select s.part_id into pid
	 from  mymes.work_report w, mymes.serials s
	 where w.id = NEW.parent_id
	 and s.id = w.serial_id;

 

    select id into test from mymes.identifier where name = NEW.name and parent_id = pid;

  IF (test > 0  ) THEN

  RETURN null ;

 END IF;
 
 IF (pid < 1 ) THEN
  RAISE EXCEPTION 'Identifier has no legitimate parent.';
  RETURN NULL ;
 END IF; 

 NEW.parent_id = pid;
 RETURN NEW ;
END ; 

$$;


--
-- TOC entry 356 (class 1255 OID 26427)
-- Name: resources_by_parent(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resources_by_parent(res integer) RETURNS TABLE(resource integer, depth integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
 RETURN QUERY
 select rh2.son as resource	,rh2.depth
	from mymes.resources_hierarchy as rh1,mymes.resources_hierarchy as rh2 
 	where rh1.son = res
		and rh1.depth = 1	
		and rh2.parent = rh1.parent
		
union

select rh1.parent,0
	from mymes.resources_hierarchy as rh1
	where rh1.son = res
 		and rh1.depth = 1;
		
END; $$;


--
-- TOC entry 341 (class 1255 OID 17023)
-- Name: set_availabilities(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_availabilities(apid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
   counter INTEGER := 0 ; 
BEGIN
 
 IF (apid < 1) THEN
 RETURN 0 ;
 END IF; 
 
 LOOP 
 EXIT WHEN counter = 7 ; 
 counter := counter + 1 ; 
 insert into mymes.availabilities(availability_profile_id,weekday,from_time,to_time) values(apid,counter,'00:00:00','00:00:00');
 END LOOP ;
  
 RETURN apid ;
END ; 
$$;


--
-- TOC entry 365 (class 1255 OID 27308)
-- Name: set_fault_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_fault_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
    pid integer;

BEGIN

IF (NEW.fault_status_id is null ) then 
	select id into pid from mymes.fault_status where first = true;
	NEW.fault_status_id = pid;
END IF; 	


 RETURN NEW ;
END ;

$$;


--
-- TOC entry 372 (class 1255 OID 26940)
-- Name: set_name(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_name() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
    num integer;
	pre text;
	
BEGIN

if (NEW.name > '' ) then 
	return NEW;
END IF; 	

select numerator,prefix into num,pre from mymes.numerators where row_type = NEW.row_type;

 IF (num < 0 ) THEN
 RAISE EXCEPTION 'Numerator out of bound for schema: %', NEW.row_type;
 RETURN NULL ;
 END IF; 
 
 select  pre || num::text into NEW.name; 
 
 update mymes.numerators
 set numerator = numerator +1
 where row_type = NEW.row_type;
 
 RETURN NEW ;
END ;

$$;


--
-- TOC entry 393 (class 1255 OID 35688)
-- Name: trig_cond_to_string(json, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trig_cond_to_string(trig_cond json, old_logic_gate text) RETURNS text
    LANGUAGE plpgsql
    AS $$	
   DECLARE
	   logic_gate text;
	   logic_condition text ;
	   items json;
	   i text;
	   lg text ;
	   start_with text;
	   ov text;
   BEGIN
	  logic_gate = (trig_cond::json->'groupName');
	  raise log '% | % |',logic_gate,logic_gate::text ;
	  return '';

	  items = trig_cond->'items';
	  logic_condition = '1=1';
      if (logic_gate = 'and') then
	  	logic_condition = '1=2';
	  end if;

      if(old_logic_gate is null) then lg = logic_gate ;
	  else lg = old_logic_gate;
	  end if;

	  
      start_with = lg || ' ( ' || logic_condition || ' ';
	  /*raise log 'Hello trig_cond_to_string % : ' ,trig_cond;*/
	  FOR i IN SELECT * FROM json_array_elements(items)
	  LOOP
	  	 
	  	if (i::json->'groupName' is not null) then
			start_with = start_with || trig_cond_to_string(i::json,logic_gate);
		else
			ov = (i::json->'operator')::text || ' ' || (i::json->'value')::text ;
			start_with = start_with || ' ' || logic_gate || ' ' || (i::json->'field')::text || ' ' || ov;
				
		end if;	
		raise log '% | % | %',logic_gate,old_logic_gate,start_with;
	  END LOOP;
	  start_with = start_with || ')';
	  return start_with || logic_gate;
   END;
$$;


--
-- TOC entry 384 (class 1255 OID 27478)
-- Name: trigger_set_sig_date(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_set_sig_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.sig_date = NOW();
  RETURN NEW;
END;
$$;


--
-- TOC entry 373 (class 1255 OID 26976)
-- Name: trigger_set_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_set_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- TOC entry 364 (class 1255 OID 25473)
-- Name: update_serial_act_balance(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_serial_act_balance(pid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare bal integer;
declare maxqnt integer;
declare serial_act_id integer;
declare qnt integer;

BEGIN
 
 select sa.id,sa.balance,sa.quant, w.quant into serial_act_id,bal,maxqnt,qnt
 from mymes.serial_act as sa, mymes.work_report as w
 where sa.serial_id = w.serial_id
 and sa.act_id = w.act_id
 and w.id = pid;
 
 IF (qnt > bal) THEN qnt = bal;
 END IF;
 qnt = qnt * -1;
 
 IF (serial_act_id <= 0 or bal < 0  or maxqnt < 0 or qnt = 0) THEN
 RAISE EXCEPTION 'update_serial_act_balance_dd - parameters error %-%-% ',serial_act_id,maxqnt,qnt;
 RETURN 0 ;
 END IF; 
 RAISE NOTICE 'Value: %', serial_act_id;
 
  IF ((bal - qnt) < 0 or (bal - qnt) > maxqnt ) THEN
 RAISE EXCEPTION 'update_serial_act_balance_d - fulty balance';
 RETURN 0 ;
 END IF;
 
 update mymes.serial_act 
 	set balance = balance - qnt
	where id = serial_act_id;

 RETURN 1 ;
END ; 

$$;


--
-- TOC entry 386 (class 1255 OID 27276)
-- Name: update_serial_act_balance(integer[], text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_serial_act_balance(pids integer[], params text[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare bal integer;
declare maxqnt integer;
declare serial_act_id integer;
declare qnt integer;
declare pid integer;

BEGIN
 
  FOREACH pid IN ARRAY pids
  LOOP

	 select sa.id,sa.balance,sa.quant, w.quant into serial_act_id,bal,maxqnt,qnt
	 from mymes.serial_act as sa, mymes.work_report as w
	 where sa.serial_id = w.serial_id
	 and sa.act_id = w.act_id
	 and w.id = pid;

	 IF (qnt + bal > maxqnt ) THEN qnt = maxqnt - bal;
	 END IF;
	 qnt = qnt * -1;

	 IF (serial_act_id <= 0 or bal < 0  or maxqnt < 0 ) THEN
	 RAISE EXCEPTION 'update_serial_act_balance_d - parameters error %, %, %, %, %',pid,serial_act_id,bal,maxqnt,qnt;
	 RETURN 0 ;
	 END IF; 
	 RAISE NOTICE 'Value: %', serial_act_id;

	  IF (bal <> 0 and((bal - qnt) < 0 or (bal - qnt) > maxqnt )) THEN
	 RAISE EXCEPTION 'update_serial_act_balance_d - fulty balance';
	 RETURN 0 ;
	 END IF;

	 update mymes.serial_act 
		set balance = balance - qnt
		where id = serial_act_id;
    
  END LOOP;
 RETURN 1 ;
END ; 

$$;


--
-- TOC entry 360 (class 1255 OID 25470)
-- Name: update_serial_act_balance(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_serial_act_balance(serial_name text, act_name text, qnt integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare bal integer;
declare maxqnt integer;
declare serial_act_id integer;
	
BEGIN
 
 select sa.id,sa.balance,sa.quant into serial_act_id,bal,maxqnt
 from mymes.serial_act as sa, mymes.serials as s,mymes.actions as a
 where sa.serial_id = s.id
 and sa.act_id = a.id
 and a.name = act_name
 and s.name = serial_name;
 IF (serial_act_id <= 0 or serial_name = '' or act_name = '' or qnt = 0) THEN
 RAISE EXCEPTION 'update_serial_act_balance - parameters error %',serial_act_id;
 RETURN 0 ;
 END IF; 
 RAISE NOTICE 'Value: %', serial_act_id;
 
  IF ((bal - qnt) < 0 or (bal - qnt) > maxqnt ) THEN
 RAISE EXCEPTION 'update_serial_act_balance - fulty balance';
 RETURN 0 ;
 END IF;
 
 update mymes.serial_act 
 	set balance = balance - qnt
	where id = serial_act_id;

 RETURN 1 ;
END ; 

$$;


--
-- TOC entry 358 (class 1255 OID 26430)
-- Name: user_parent_resources(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_parent_resources(usr character varying) RETURNS TABLE(resource integer, depth integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
 RETURN QUERY
 select rh.parent as resource,rh.depth
	from mymes.resources_hierarchy as rh, users ,mymes.employees emp
 	where rh.son = emp.id
		and emp.user_id = users.id
		and username = usr;
END; $$;


--
-- TOC entry 376 (class 1255 OID 26968)
-- Name: user_parent_users(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_parent_users(usr character varying) RETURNS TABLE(username character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
 RETURN QUERY
	select users.username
		from user_parent_resources(usr) as xxx, mymes.employees as e, mymes.resources_hierarchy as rh , users
		where rh.parent = xxx.resource
		and e.id = rh.son
		and xxx.depth > 1
		and rh.depth = 1
		and users.id  = e.user_id ;
 
END; $$;


--
-- TOC entry 357 (class 1255 OID 26429)
-- Name: user_resources_by_parent(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_resources_by_parent(usrname character varying) RETURNS TABLE(resource integer, depth integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
 RETURN QUERY
 select rh2.son as resource	,rh2.depth
	from mymes.resources_hierarchy as rh1,mymes.resources_hierarchy as rh2 ,users ,mymes.employees emp
 	where rh1.son = emp.id
		and rh1.depth = 1	
		and rh2.parent = rh1.parent
		and emp.user_id = users.id
		and username = usrname
		
union

select rh1.parent,0
	from mymes.resources_hierarchy as rh1, users ,mymes.employees emp
	where rh1.son = emp.id
 		and rh1.depth = 1
		and emp.user_id = users.id
		and username = usrname;		
		
END; $$;


--
-- TOC entry 368 (class 1255 OID 26492)
-- Name: work_report_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.work_report_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

begin
 insert into mymes.notifications(title,type,username)
     with payload(serial_name,act_name) as
     (
       select s.name as serial_name , a.name as act_name 
		 from	 mymes.serials s, mymes.actions a 
		 where s.id = NEW.serial_id
		 and a.id = NEW.act_id
     ) 
     select 'The ' || act_name || ' action of '|| serial_name || 'work order had finished' as title,
	  'event' as type,  
	  res.name as usr
      from payload, resources_by_parent(NEW.resource_id) as parents, mymes.resources as res
	  where res.id = parents.resource;
  RETURN NULL;
end;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 226 (class 1259 OID 16965)
-- Name:  utilization; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes." utilization" (
    id integer NOT NULL,
    resource_id integer NOT NULL,
    udate daterange
);


--
-- TOC entry 225 (class 1259 OID 16963)
-- Name:  utilization_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes." utilization_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3912 (class 0 OID 0)
-- Dependencies: 225
-- Name:  utilization_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes." utilization_id_seq" OWNED BY mymes." utilization".id;


--
-- TOC entry 204 (class 1259 OID 16557)
-- Name: permissions; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.permissions (
    entity integer NOT NULL,
    field integer,
    read boolean,
    write boolean,
    delete boolean,
    profile_id integer,
    id integer NOT NULL,
    ws smallint
);


--
-- TOC entry 206 (class 1259 OID 16697)
-- Name: PERMISSIONS_PERMISION_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes."PERMISSIONS_PERMISION_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3913 (class 0 OID 0)
-- Dependencies: 206
-- Name: PERMISSIONS_PERMISION_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes."PERMISSIONS_PERMISION_seq" OWNED BY mymes.permissions.id;


--
-- TOC entry 304 (class 1259 OID 26388)
-- Name: act_resources; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.act_resources (
    resource_id integer NOT NULL,
    act_id integer NOT NULL,
    id integer NOT NULL,
    ord smallint NOT NULL,
    type smallint NOT NULL
);


--
-- TOC entry 303 (class 1259 OID 26386)
-- Name: act_resources_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.act_resources_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3914 (class 0 OID 0)
-- Dependencies: 303
-- Name: act_resources_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.act_resources_id_seq OWNED BY mymes.act_resources.id;


--
-- TOC entry 252 (class 1259 OID 17215)
-- Name: tagable; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.tagable (
    tags text[],
    row_type public.row_type,
    name text NOT NULL,
    id integer NOT NULL
);


--
-- TOC entry 261 (class 1259 OID 25207)
-- Name: actions; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.actions (
    id integer,
    name text,
    tags text[],
    row_type public.row_type,
    active boolean,
    erpact text,
    quantitative boolean,
    serialize boolean
)
INHERITS (mymes.tagable);


--
-- TOC entry 260 (class 1259 OID 25205)
-- Name: actions_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3915 (class 0 OID 0)
-- Dependencies: 260
-- Name: actions_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.actions_id_seq OWNED BY mymes.actions.id;


--
-- TOC entry 262 (class 1259 OID 25216)
-- Name: actions_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.actions_t (
    action_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 292 (class 1259 OID 25528)
-- Name: resource_timeoff; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.resource_timeoff (
    id integer NOT NULL,
    from_date timestamp(6) without time zone NOT NULL,
    to_date timestamp(6) without time zone NOT NULL,
    resource_id integer NOT NULL,
    flag_o boolean,
    parent_id integer,
    ts_range tsrange,
    approval public.approval,
    request text,
    approved_by integer
);


--
-- TOC entry 291 (class 1259 OID 25526)
-- Name: ap_holidays_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.ap_holidays_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3916 (class 0 OID 0)
-- Dependencies: 291
-- Name: ap_holidays_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.ap_holidays_id_seq OWNED BY mymes.resource_timeoff.id;


--
-- TOC entry 224 (class 1259 OID 16960)
-- Name: availabilities; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.availabilities (
    availability_profile_id integer NOT NULL,
    weekday smallint NOT NULL,
    from_time time(6) without time zone,
    to_time time(6) without time zone,
    id integer NOT NULL,
    flag_o boolean
);


--
-- TOC entry 228 (class 1259 OID 17015)
-- Name: availabilities_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.availabilities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3917 (class 0 OID 0)
-- Dependencies: 228
-- Name: availabilities_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.availabilities_id_seq OWNED BY mymes.availabilities.id;


--
-- TOC entry 223 (class 1259 OID 16954)
-- Name: availability_profiles; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.availability_profiles (
    id integer,
    name text,
    active boolean,
    tags text[],
    row_type public.row_type
)
INHERITS (mymes.tagable);


--
-- TOC entry 222 (class 1259 OID 16952)
-- Name: availability_profile_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.availability_profile_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3918 (class 0 OID 0)
-- Dependencies: 222
-- Name: availability_profile_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.availability_profile_id_seq OWNED BY mymes.availability_profiles.id;


--
-- TOC entry 227 (class 1259 OID 16997)
-- Name: availability_profiles_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.availability_profiles_t (
    ap_id integer NOT NULL,
    description text,
    lang_id integer NOT NULL
);


--
-- TOC entry 280 (class 1259 OID 25368)
-- Name: bom; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.bom (
    id integer NOT NULL,
    parent_id integer NOT NULL,
    partname text NOT NULL,
    coef real NOT NULL,
    produce boolean
);


--
-- TOC entry 279 (class 1259 OID 25366)
-- Name: bom_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.bom_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3919 (class 0 OID 0)
-- Dependencies: 279
-- Name: bom_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.bom_id_seq OWNED BY mymes.bom.id;


--
-- TOC entry 337 (class 1259 OID 27488)
-- Name: event_triggers; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.event_triggers (
    id integer NOT NULL,
    name text NOT NULL,
    active boolean,
    message_text text,
    queues text[],
    error boolean,
    conditions text,
    table_id text,
    user_name text,
    update_sql text,
    insert_sql text,
    del boolean
);


--
-- TOC entry 336 (class 1259 OID 27486)
-- Name: checks_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.checks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3920 (class 0 OID 0)
-- Dependencies: 336
-- Name: checks_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.checks_id_seq OWNED BY mymes.event_triggers.id;


--
-- TOC entry 210 (class 1259 OID 16858)
-- Name: configurations; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.configurations (
    key character varying NOT NULL,
    intarray integer[]
);


--
-- TOC entry 307 (class 1259 OID 26502)
-- Name: convers; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.convers (
    id integer,
    row_type public.row_type,
    messsage text,
    author text,
    "user" integer,
    udate timestamp without time zone
);


--
-- TOC entry 209 (class 1259 OID 16836)
-- Name: departments; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.departments (
    name text,
    id integer,
    tags text[],
    row_type public.row_type
)
INHERITS (mymes.tagable);


--
-- TOC entry 208 (class 1259 OID 16834)
-- Name: departments_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.departments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3921 (class 0 OID 0)
-- Dependencies: 208
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.departments_id_seq OWNED BY mymes.departments.id;


--
-- TOC entry 207 (class 1259 OID 16831)
-- Name: departments_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.departments_t (
    description character varying(80) NOT NULL,
    dept_id integer NOT NULL,
    lang_id integer NOT NULL
);


--
-- TOC entry 218 (class 1259 OID 16920)
-- Name: resources; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.resources (
    id integer,
    level smallint DEFAULT 0,
    availability_profile_id integer NOT NULL,
    name text,
    active boolean,
    row_type public.row_type,
    tags text[] DEFAULT ARRAY[]::text[],
    resource_ids integer[],
    dragable boolean
)
INHERITS (mymes.tagable);


--
-- TOC entry 219 (class 1259 OID 16926)
-- Name: employees; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.employees (
    name text,
    user_id integer,
    salary_n text DEFAULT ''::text,
    clock_n text DEFAULT ''::text,
    id_n text DEFAULT ''::text,
    resource_ids integer[],
    delivery_method public.delivery_method,
    email text,
    phone text,
    position_id integer
)
INHERITS (mymes.resources);


--
-- TOC entry 202 (class 1259 OID 16540)
-- Name: employees_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.employees_t (
    emp_id integer,
    lang_id integer,
    fname text NOT NULL,
    sname text,
    ws smallint
);


--
-- TOC entry 220 (class 1259 OID 16930)
-- Name: equipments; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.equipments (
    name text,
    mac_address macaddr,
    serial text,
    equipment_type public.equipment_type,
    calibrated boolean,
    resource_ids integer[],
    last_calibration timestamp without time zone
)
INHERITS (mymes.resources);


--
-- TOC entry 203 (class 1259 OID 16543)
-- Name: equipments_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.equipments_t (
    equipment_id integer,
    lang_id integer,
    description text,
    ws smallint
);


--
-- TOC entry 317 (class 1259 OID 26688)
-- Name: sendable; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.sendable (
    id integer NOT NULL,
    row_type public.row_type,
    resource_id integer,
    act_id integer,
    serial_id integer,
    sig_date timestamp(6) without time zone,
    sig_user integer,
    sent boolean,
    approved boolean
);


--
-- TOC entry 313 (class 1259 OID 26557)
-- Name: fault; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fault (
    id integer,
    name text,
    serial_id integer,
    fault_status_id integer,
    fault_type_id integer NOT NULL,
    quant real,
    tags text[],
    row_type public.row_type,
    close_date timestamp(6) without time zone,
    resource_id integer,
    act_id integer,
    sig_date timestamp(6) without time zone,
    sig_user integer NOT NULL,
    sent boolean,
    approved boolean,
    location_id integer,
    fix_id integer
)
INHERITS (mymes.tagable, mymes.sendable);


--
-- TOC entry 311 (class 1259 OID 26542)
-- Name: fault_status; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fault_status (
    id integer,
    name text,
    tags text[],
    row_type public.row_type,
    active boolean,
    first boolean,
    sendable boolean
)
INHERITS (mymes.tagable);


--
-- TOC entry 315 (class 1259 OID 26575)
-- Name: fault_status_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fault_status_t (
    fault_status_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 316 (class 1259 OID 26581)
-- Name: fault_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fault_t (
    fault_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 309 (class 1259 OID 26518)
-- Name: fault_type; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fault_type (
    name text,
    id integer,
    tags text[],
    row_type public.row_type,
    active boolean,
    extname text
)
INHERITS (mymes.tagable);


--
-- TOC entry 323 (class 1259 OID 27277)
-- Name: fault_type_act; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fault_type_act (
    fault_type_id integer NOT NULL,
    action_id integer NOT NULL,
    id integer NOT NULL
);


--
-- TOC entry 324 (class 1259 OID 27287)
-- Name: fault_type_act_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.fault_type_act_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3922 (class 0 OID 0)
-- Dependencies: 324
-- Name: fault_type_act_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.fault_type_act_id_seq OWNED BY mymes.fault_type_act.id;


--
-- TOC entry 314 (class 1259 OID 26569)
-- Name: fault_type_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fault_type_t (
    fault_type_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 326 (class 1259 OID 27341)
-- Name: fix; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fix (
    name text NOT NULL,
    id integer NOT NULL,
    tags text[],
    row_type public.row_type,
    active boolean,
    extname text
);


--
-- TOC entry 330 (class 1259 OID 27383)
-- Name: fix_act; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fix_act (
    fix_id integer NOT NULL,
    action_id integer NOT NULL,
    id integer NOT NULL
);


--
-- TOC entry 329 (class 1259 OID 27381)
-- Name: fix_act_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.fix_act_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3923 (class 0 OID 0)
-- Dependencies: 329
-- Name: fix_act_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.fix_act_id_seq OWNED BY mymes.fix_act.id;


--
-- TOC entry 325 (class 1259 OID 27339)
-- Name: fix_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.fix_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3924 (class 0 OID 0)
-- Dependencies: 325
-- Name: fix_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.fix_id_seq OWNED BY mymes.fix.id;


--
-- TOC entry 328 (class 1259 OID 27356)
-- Name: fix_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.fix_t (
    fix_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 327 (class 1259 OID 27354)
-- Name: fix_t_fix_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.fix_t_fix_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3925 (class 0 OID 0)
-- Dependencies: 327
-- Name: fix_t_fix_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.fix_t_fix_id_seq OWNED BY mymes.fix_t.fix_id;


--
-- TOC entry 288 (class 1259 OID 25478)
-- Name: identifier; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.identifier (
    id integer NOT NULL,
    name text NOT NULL,
    parent_id integer,
    created_at timestamp(6) with time zone DEFAULT now(),
    parent_identifier_id integer,
    mac_address macaddr,
    secondary text,
    batch text
);


--
-- TOC entry 318 (class 1259 OID 26693)
-- Name: identifier_links; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.identifier_links (
    identifier_id bigint NOT NULL,
    parent_id integer NOT NULL,
    row_type public.row_type NOT NULL,
    serial_id integer,
    act_id integer,
    created_at timestamp(6) with time zone DEFAULT now(),
    batch_array integer[]
);


--
-- TOC entry 287 (class 1259 OID 25476)
-- Name: identifiers_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.identifiers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3926 (class 0 OID 0)
-- Dependencies: 287
-- Name: identifiers_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.identifiers_id_seq OWNED BY mymes.identifier.id;


--
-- TOC entry 266 (class 1259 OID 25246)
-- Name: import_schamas_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.import_schamas_t (
    import_schama_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 265 (class 1259 OID 25237)
-- Name: import_schemas; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.import_schemas (
    id integer NOT NULL,
    name text NOT NULL,
    schema text NOT NULL
);


--
-- TOC entry 264 (class 1259 OID 25235)
-- Name: import_schemas_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.import_schemas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3927 (class 0 OID 0)
-- Dependencies: 264
-- Name: import_schemas_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.import_schemas_id_seq OWNED BY mymes.import_schemas.id;


--
-- TOC entry 263 (class 1259 OID 25227)
-- Name: kit; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.kit (
    serial_id integer NOT NULL,
    partname text NOT NULL,
    quant real NOT NULL,
    lot text,
    balance real,
    id bigint NOT NULL,
    in_use boolean
);


--
-- TOC entry 281 (class 1259 OID 25377)
-- Name: kit_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.kit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3928 (class 0 OID 0)
-- Dependencies: 281
-- Name: kit_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.kit_id_seq OWNED BY mymes.kit.id;


--
-- TOC entry 333 (class 1259 OID 27449)
-- Name: kit_usage; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.kit_usage (
    kit_id integer NOT NULL,
    start_date timestamp without time zone NOT NULL,
    stop_date timestamp without time zone NOT NULL,
    usage integer NOT NULL
);


--
-- TOC entry 198 (class 1259 OID 16470)
-- Name: languages; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.languages (
    name character varying(20) NOT NULL,
    id integer NOT NULL
);


--
-- TOC entry 283 (class 1259 OID 25410)
-- Name: local_actions; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.local_actions (
    id integer NOT NULL,
    name text NOT NULL,
    command text,
    type_sig text
);


--
-- TOC entry 282 (class 1259 OID 25408)
-- Name: local_actions_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.local_actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3929 (class 0 OID 0)
-- Dependencies: 282
-- Name: local_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.local_actions_id_seq OWNED BY mymes.local_actions.id;


--
-- TOC entry 284 (class 1259 OID 25431)
-- Name: local_actions_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.local_actions_t (
    local_action_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);


--
-- TOC entry 259 (class 1259 OID 25192)
-- Name: locations; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.locations (
    part_id integer NOT NULL,
    act_id integer,
    location text NOT NULL,
    partname text NOT NULL,
    quant real NOT NULL,
    id bigint NOT NULL,
    x real,
    y real,
    z real
);


--
-- TOC entry 271 (class 1259 OID 25290)
-- Name: locations_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.locations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3930 (class 0 OID 0)
-- Dependencies: 271
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.locations_id_seq OWNED BY mymes.locations.id;


--
-- TOC entry 334 (class 1259 OID 27454)
-- Name: lot_swap; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.lot_swap (
    resource_id integer NOT NULL,
    serial_id integer NOT NULL,
    act_id integer NOT NULL,
    user_id integer NOT NULL,
    lot_old text,
    lot_new text NOT NULL,
    updated_at timestamp without time zone,
    id bigint NOT NULL
);


--
-- TOC entry 335 (class 1259 OID 27466)
-- Name: lot_swap_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.lot_swap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3931 (class 0 OID 0)
-- Dependencies: 335
-- Name: lot_swap_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.lot_swap_id_seq OWNED BY mymes.lot_swap.id;


--
-- TOC entry 312 (class 1259 OID 26555)
-- Name: malf_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.malf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3932 (class 0 OID 0)
-- Dependencies: 312
-- Name: malf_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.malf_id_seq OWNED BY mymes.fault.id;


--
-- TOC entry 310 (class 1259 OID 26540)
-- Name: malf_status_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.malf_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3933 (class 0 OID 0)
-- Dependencies: 310
-- Name: malf_status_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.malf_status_id_seq OWNED BY mymes.fault_status.id;


--
-- TOC entry 308 (class 1259 OID 26516)
-- Name: malf_type_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.malf_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3934 (class 0 OID 0)
-- Dependencies: 308
-- Name: malf_type_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.malf_type_id_seq OWNED BY mymes.fault_type.id;


--
-- TOC entry 237 (class 1259 OID 17107)
-- Name: malfunction_types; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.malfunction_types (
    id integer NOT NULL,
    name text NOT NULL
);


--
-- TOC entry 236 (class 1259 OID 17105)
-- Name: malfunction_types_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.malfunction_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3935 (class 0 OID 0)
-- Dependencies: 236
-- Name: malfunction_types_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.malfunction_types_id_seq OWNED BY mymes.malfunction_types.id;


--
-- TOC entry 241 (class 1259 OID 17142)
-- Name: malfunction_types_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.malfunction_types_t (
    malfunction_type_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 235 (class 1259 OID 17077)
-- Name: malfunctions; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.malfunctions (
    id integer,
    name text,
    dept_id integer,
    open_date timestamp(6) without time zone,
    close_date timestamp(6) without time zone,
    dead boolean DEFAULT false,
    status public.malfunction_status,
    malfunction_type_id integer,
    tags text[],
    equipment_id integer,
    row_type public.row_type
)
INHERITS (mymes.tagable);


--
-- TOC entry 234 (class 1259 OID 17075)
-- Name: malfunctions_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.malfunctions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3936 (class 0 OID 0)
-- Dependencies: 234
-- Name: malfunctions_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.malfunctions_id_seq OWNED BY mymes.malfunctions.id;


--
-- TOC entry 238 (class 1259 OID 17116)
-- Name: malfunctions_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.malfunctions_t (
    description text NOT NULL,
    malfunction_id integer NOT NULL,
    lang_id integer NOT NULL
);


--
-- TOC entry 248 (class 1259 OID 17178)
-- Name: mnt_plans; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.mnt_plans (
    id integer,
    name text,
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    repeat smallint,
    reschedule boolean,
    tags text[],
    row_type public.row_type
)
INHERITS (mymes.tagable);


--
-- TOC entry 247 (class 1259 OID 17176)
-- Name: mnt_plan_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.mnt_plan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3937 (class 0 OID 0)
-- Dependencies: 247
-- Name: mnt_plan_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.mnt_plan_id_seq OWNED BY mymes.mnt_plans.id;


--
-- TOC entry 249 (class 1259 OID 17187)
-- Name: mnt_plan_items; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.mnt_plan_items (
    mnt_plan_id integer NOT NULL,
    resource_id integer NOT NULL,
    id integer NOT NULL
);


--
-- TOC entry 251 (class 1259 OID 17196)
-- Name: mnt_plan_items_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.mnt_plan_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3938 (class 0 OID 0)
-- Dependencies: 251
-- Name: mnt_plan_items_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.mnt_plan_items_id_seq OWNED BY mymes.mnt_plan_items.id;


--
-- TOC entry 250 (class 1259 OID 17190)
-- Name: mnt_plans_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.mnt_plans_t (
    mnt_plan_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 295 (class 1259 OID 25582)
-- Name: notifications; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.notifications (
    id integer NOT NULL,
    name text,
    title text,
    avatar text,
    icon text,
    read boolean,
    type public.notifications_type NOT NULL,
    status text,
    extra text,
    username text,
    schema text
);


--
-- TOC entry 294 (class 1259 OID 25580)
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3939 (class 0 OID 0)
-- Dependencies: 294
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.notifications_id_seq OWNED BY mymes.notifications.id;


--
-- TOC entry 319 (class 1259 OID 26927)
-- Name: numerators; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.numerators (
    numerator integer NOT NULL,
    prefix text NOT NULL,
    row_type public.row_type NOT NULL,
    description text NOT NULL,
    id integer NOT NULL
);


--
-- TOC entry 320 (class 1259 OID 27033)
-- Name: numerators_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.numerators_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3940 (class 0 OID 0)
-- Dependencies: 320
-- Name: numerators_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.numerators_id_seq OWNED BY mymes.numerators.id;


--
-- TOC entry 212 (class 1259 OID 16868)
-- Name: part; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.part (
    id integer,
    name text,
    part_status_id integer,
    tags text[],
    row_type public.row_type,
    revision text,
    active boolean,
    doc_revision text,
    serialize boolean,
    updated_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    batch_size integer
)
INHERITS (mymes.tagable);


--
-- TOC entry 211 (class 1259 OID 16866)
-- Name: part_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.part_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3941 (class 0 OID 0)
-- Dependencies: 211
-- Name: part_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.part_id_seq OWNED BY mymes.part.id;


--
-- TOC entry 215 (class 1259 OID 16888)
-- Name: part_status; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.part_status (
    id integer,
    name text,
    row_type public.row_type,
    tags text[],
    active boolean
)
INHERITS (mymes.tagable);


--
-- TOC entry 214 (class 1259 OID 16886)
-- Name: part_status_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.part_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3942 (class 0 OID 0)
-- Dependencies: 214
-- Name: part_status_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.part_status_id_seq OWNED BY mymes.part_status.id;


--
-- TOC entry 216 (class 1259 OID 16894)
-- Name: part_status_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.part_status_t (
    part_status_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);


--
-- TOC entry 213 (class 1259 OID 16876)
-- Name: part_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.part_t (
    part_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);


--
-- TOC entry 301 (class 1259 OID 26351)
-- Name: positions; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.positions (
    id integer,
    name text,
    qa boolean,
    hr boolean,
    tags text[],
    row_type public.row_type NOT NULL,
    manager boolean
)
INHERITS (mymes.tagable);


--
-- TOC entry 300 (class 1259 OID 26349)
-- Name: positions_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.positions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3943 (class 0 OID 0)
-- Dependencies: 300
-- Name: positions_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.positions_id_seq OWNED BY mymes.positions.id;


--
-- TOC entry 302 (class 1259 OID 26360)
-- Name: positions_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.positions_t (
    position_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);


--
-- TOC entry 290 (class 1259 OID 25497)
-- Name: preferences; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.preferences (
    id integer NOT NULL,
    name text,
    description text,
    value text
);


--
-- TOC entry 289 (class 1259 OID 25495)
-- Name: preferences_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.preferences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3944 (class 0 OID 0)
-- Dependencies: 289
-- Name: preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.preferences_id_seq OWNED BY mymes.preferences.id;


--
-- TOC entry 276 (class 1259 OID 25327)
-- Name: proc_act; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.proc_act (
    id integer NOT NULL,
    process_id integer,
    act_id integer,
    pos smallint,
    quantitative boolean,
    serialize boolean,
    batch boolean
);


--
-- TOC entry 275 (class 1259 OID 25325)
-- Name: proc_act_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.proc_act_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3945 (class 0 OID 0)
-- Dependencies: 275
-- Name: proc_act_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.proc_act_id_seq OWNED BY mymes.proc_act.id;


--
-- TOC entry 273 (class 1259 OID 25304)
-- Name: process; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.process (
    name text,
    id integer,
    erpproc text,
    active boolean
)
INHERITS (mymes.tagable);


--
-- TOC entry 272 (class 1259 OID 25302)
-- Name: process_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.process_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3946 (class 0 OID 0)
-- Dependencies: 272
-- Name: process_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.process_id_seq OWNED BY mymes.process.id;


--
-- TOC entry 274 (class 1259 OID 25315)
-- Name: process_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.process_t (
    process_id integer NOT NULL,
    description text NOT NULL,
    lang_id integer NOT NULL
);


--
-- TOC entry 245 (class 1259 OID 17161)
-- Name: repair_types; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.repair_types (
    id integer NOT NULL,
    name text NOT NULL
);


--
-- TOC entry 244 (class 1259 OID 17159)
-- Name: repair_types_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.repair_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3947 (class 0 OID 0)
-- Dependencies: 244
-- Name: repair_types_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.repair_types_id_seq OWNED BY mymes.repair_types.id;


--
-- TOC entry 246 (class 1259 OID 17170)
-- Name: repair_types_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.repair_types_t (
    repair_type_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 243 (class 1259 OID 17150)
-- Name: repairs; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.repairs (
    id integer,
    name text,
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    details text,
    malfunction_id integer,
    employee_id integer,
    repair_type_id integer NOT NULL,
    tags text[],
    row_type public.row_type
)
INHERITS (mymes.tagable);


--
-- TOC entry 242 (class 1259 OID 17148)
-- Name: repairs_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.repairs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3948 (class 0 OID 0)
-- Dependencies: 242
-- Name: repairs_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.repairs_id_seq OWNED BY mymes.repairs.id;


--
-- TOC entry 298 (class 1259 OID 26313)
-- Name: resource_arc; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.resource_arc (
    parent_id integer NOT NULL,
    son_id integer NOT NULL,
    ord smallint,
    id integer NOT NULL
);


--
-- TOC entry 299 (class 1259 OID 26338)
-- Name: resource_arc_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.resource_arc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3949 (class 0 OID 0)
-- Dependencies: 299
-- Name: resource_arc_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.resource_arc_id_seq OWNED BY mymes.resource_arc.id;


--
-- TOC entry 205 (class 1259 OID 16626)
-- Name: resource_groups_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.resource_groups_t (
    resource_group_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text,
    ws smallint
);


--
-- TOC entry 297 (class 1259 OID 26309)
-- Name: resource_desc; Type: VIEW; Schema: mymes; Owner: -
--

CREATE VIEW mymes.resource_desc AS
 SELECT equipments_t.equipment_id AS resource_id,
    equipments_t.description,
    equipments_t.lang_id
   FROM mymes.equipments_t
UNION
 SELECT resource_groups_t.resource_group_id AS resource_id,
    resource_groups_t.description,
    resource_groups_t.lang_id
   FROM mymes.resource_groups_t
UNION
 SELECT employees_t.emp_id AS resource_id,
    ((employees_t.fname || ' '::text) || employees_t.sname) AS description,
    employees_t.lang_id
   FROM mymes.employees_t;


--
-- TOC entry 221 (class 1259 OID 16945)
-- Name: resource_groups; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.resource_groups (
    resource_ids integer[],
    name text,
    extname text
)
INHERITS (mymes.resources);


--
-- TOC entry 305 (class 1259 OID 26422)
-- Name: resources_hierarchy; Type: VIEW; Schema: mymes; Owner: -
--

CREATE VIEW mymes.resources_hierarchy AS
 WITH RECURSIVE reporting_line AS (
         SELECT resources.id,
            resources.id AS subordinates,
            0 AS depth
           FROM mymes.resources
        UNION ALL
         SELECT e.id,
            rl.subordinates,
            (rl.depth + 1)
           FROM (mymes.resource_groups e
             JOIN reporting_line rl ON ((rl.id = ANY (e.resource_ids))))
        )
 SELECT DISTINCT reporting_line.id AS parent,
    reporting_line.subordinates AS son,
    reporting_line.depth
   FROM reporting_line;


--
-- TOC entry 306 (class 1259 OID 26495)
-- Name: resource_level; Type: VIEW; Schema: mymes; Owner: -
--

CREATE VIEW mymes.resource_level AS
 SELECT resources_hierarchy.parent AS resource,
    max(resources_hierarchy.depth) AS level
   FROM mymes.resources_hierarchy
  GROUP BY resources_hierarchy.parent
  ORDER BY (max(resources_hierarchy.depth)) DESC;


--
-- TOC entry 217 (class 1259 OID 16918)
-- Name: resources_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.resources_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3950 (class 0 OID 0)
-- Dependencies: 217
-- Name: resources_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.resources_id_seq OWNED BY mymes.resources.id;


--
-- TOC entry 278 (class 1259 OID 25343)
-- Name: serial_act; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.serial_act (
    serial_id integer NOT NULL,
    pos smallint NOT NULL,
    act_id integer NOT NULL,
    id integer NOT NULL,
    quant integer,
    balance integer,
    quantitative boolean,
    serialize boolean,
    batch_size integer
);


--
-- TOC entry 277 (class 1259 OID 25341)
-- Name: serial_act_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.serial_act_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3951 (class 0 OID 0)
-- Dependencies: 277
-- Name: serial_act_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.serial_act_id_seq OWNED BY mymes.serial_act.id;


--
-- TOC entry 201 (class 1259 OID 16534)
-- Name: serial_seq_LANGUAGES_LANG; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes."serial_seq_LANGUAGES_LANG"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3952 (class 0 OID 0)
-- Dependencies: 201
-- Name: serial_seq_LANGUAGES_LANG; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes."serial_seq_LANGUAGES_LANG" OWNED BY mymes.languages.id;


--
-- TOC entry 268 (class 1259 OID 25256)
-- Name: serial_statuses; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.serial_statuses (
    name text,
    id integer,
    active boolean,
    closed boolean,
    ext_status text
)
INHERITS (mymes.tagable);


--
-- TOC entry 267 (class 1259 OID 25254)
-- Name: serial_statuses_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.serial_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3953 (class 0 OID 0)
-- Dependencies: 267
-- Name: serial_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.serial_statuses_id_seq OWNED BY mymes.serial_statuses.id;


--
-- TOC entry 269 (class 1259 OID 25263)
-- Name: serial_statuses_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.serial_statuses_t (
    serial_status_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 258 (class 1259 OID 25185)
-- Name: serials; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.serials (
    name text,
    id integer,
    end_date timestamp(6) without time zone,
    active boolean,
    status integer,
    part_id integer,
    process_id integer,
    quant integer,
    extserial text,
    parent_serial integer
)
INHERITS (mymes.tagable);


--
-- TOC entry 257 (class 1259 OID 25183)
-- Name: serials_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.serials_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3954 (class 0 OID 0)
-- Dependencies: 257
-- Name: serials_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.serials_id_seq OWNED BY mymes.serials.id;


--
-- TOC entry 270 (class 1259 OID 25271)
-- Name: serials_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.serials_t (
    serial_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 230 (class 1259 OID 17026)
-- Name: standards; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.standards (
    id integer NOT NULL,
    name text NOT NULL,
    resource_id integer NOT NULL,
    quant integer NOT NULL,
    part_id integer,
    standard_type_id smallint,
    act_id integer
);


--
-- TOC entry 229 (class 1259 OID 17024)
-- Name: standards_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.standards_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3955 (class 0 OID 0)
-- Dependencies: 229
-- Name: standards_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.standards_id_seq OWNED BY mymes.standards.id;


--
-- TOC entry 232 (class 1259 OID 17037)
-- Name: standards_types; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.standards_types (
    id integer NOT NULL,
    name text
);


--
-- TOC entry 231 (class 1259 OID 17035)
-- Name: standards_types_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.standards_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3956 (class 0 OID 0)
-- Dependencies: 231
-- Name: standards_types_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.standards_types_id_seq OWNED BY mymes.standards_types.id;


--
-- TOC entry 233 (class 1259 OID 17046)
-- Name: standards_types_t; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.standards_types_t (
    lang_id integer NOT NULL,
    standard_type_id smallint NOT NULL,
    description text
);


--
-- TOC entry 340 (class 1259 OID 27536)
-- Name: tables; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.tables (
    id smallint NOT NULL,
    name text NOT NULL,
    row_type public.row_type
);


--
-- TOC entry 339 (class 1259 OID 27534)
-- Name: tables_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.tables_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3957 (class 0 OID 0)
-- Dependencies: 339
-- Name: tables_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.tables_id_seq OWNED BY mymes.tables.id;


--
-- TOC entry 286 (class 1259 OID 25446)
-- Name: work_report; Type: TABLE; Schema: mymes; Owner: -
--

CREATE TABLE mymes.work_report (
    id integer,
    serial_id integer NOT NULL,
    act_id integer NOT NULL,
    quant integer NOT NULL,
    sig_date timestamp(6) without time zone NOT NULL,
    sig_user integer NOT NULL,
    resource_id integer,
    sent boolean,
    approved boolean,
    row_type public.row_type
)
INHERITS (mymes.sendable);


--
-- TOC entry 285 (class 1259 OID 25444)
-- Name: work_report_id_seq; Type: SEQUENCE; Schema: mymes; Owner: -
--

CREATE SEQUENCE mymes.work_report_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3958 (class 0 OID 0)
-- Dependencies: 285
-- Name: work_report_id_seq; Type: SEQUENCE OWNED BY; Schema: mymes; Owner: -
--

ALTER SEQUENCE mymes.work_report_id_seq OWNED BY mymes.work_report.id;


--
-- TOC entry 200 (class 1259 OID 16522)
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    username character varying(20) NOT NULL,
    id integer NOT NULL,
    emp_id integer,
    profile_id integer,
    token text NOT NULL,
    password_digest text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    email text,
    tags text[],
    "currentAuthority" character varying(15),
    last_login timestamp with time zone,
    row_type public.row_type,
    title text,
    locale character varying(5)
);


--
-- TOC entry 199 (class 1259 OID 16520)
-- Name: USERS_USERID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."USERS_USERID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3959 (class 0 OID 0)
-- Dependencies: 199
-- Name: USERS_USERID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."USERS_USERID_seq" OWNED BY public.users.id;


--
-- TOC entry 254 (class 1259 OID 17229)
-- Name: bugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bugs (
    message text,
    id integer NOT NULL,
    status smallint,
    state text
);


--
-- TOC entry 253 (class 1259 OID 17227)
-- Name: bugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bugs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3960 (class 0 OID 0)
-- Dependencies: 253
-- Name: bugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bugs_id_seq OWNED BY public.bugs.id;


--
-- TOC entry 338 (class 1259 OID 27523)
-- Name: condition_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.condition_type (
    condition public.condition_t NOT NULL,
    description text NOT NULL
);


--
-- TOC entry 322 (class 1259 OID 27266)
-- Name: foreign_keys_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.foreign_keys_view AS
 SELECT tc.table_name AS son_table,
    kcu.column_name AS son_column,
    ccu.table_name AS parent_table,
    ccu.column_name AS parent_column
   FROM ((information_schema.table_constraints tc
     JOIN information_schema.key_column_usage kcu ON ((((tc.constraint_name)::text = (kcu.constraint_name)::text) AND ((tc.table_schema)::text = (kcu.table_schema)::text))))
     JOIN information_schema.constraint_column_usage ccu ON ((((ccu.constraint_name)::text = (tc.constraint_name)::text) AND ((ccu.table_schema)::text = (tc.table_schema)::text))))
  WHERE (((tc.constraint_type)::text = 'FOREIGN KEY'::text) AND ((tc.table_schema)::text = 'mymes'::text));


--
-- TOC entry 240 (class 1259 OID 17135)
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id integer NOT NULL,
    name text,
    active boolean
);


--
-- TOC entry 239 (class 1259 OID 17133)
-- Name: profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3961 (class 0 OID 0)
-- Dependencies: 239
-- Name: profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.profiles_id_seq OWNED BY public.profiles.id;


--
-- TOC entry 255 (class 1259 OID 25167)
-- Name: profiles_t; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles_t (
    profile_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);


--
-- TOC entry 256 (class 1259 OID 25173)
-- Name: routes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routes (
    routes text
);


--
-- TOC entry 331 (class 1259 OID 27420)
-- Name: sn; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sn (
    name text
);


--
-- TOC entry 296 (class 1259 OID 26229)
-- Name: tagable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tagable (
    tags text[],
    row_type public.row_type,
    name text
);


--
-- TOC entry 321 (class 1259 OID 27064)
-- Name: test; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test (
    ts_naked timestamp without time zone,
    ts_tz timestamp with time zone
);


--
-- TOC entry 293 (class 1259 OID 25555)
-- Name: tmp; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tmp (
    from_date timestamp(6) with time zone,
    to_date timestamp(6) with time zone,
    flag_o boolean
);


--
-- TOC entry 332 (class 1259 OID 27434)
-- Name: debug; Type: TABLE; Schema: test; Owner: -
--

CREATE TABLE test.debug (
    text text
);


--
-- TOC entry 3381 (class 2604 OID 16968)
-- Name:  utilization id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes." utilization" ALTER COLUMN id SET DEFAULT nextval('mymes." utilization_id_seq"'::regclass);


--
-- TOC entry 3412 (class 2604 OID 26391)
-- Name: act_resources id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.act_resources ALTER COLUMN id SET DEFAULT nextval('mymes.act_resources_id_seq'::regclass);


--
-- TOC entry 3395 (class 2604 OID 25210)
-- Name: actions id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.actions ALTER COLUMN id SET DEFAULT nextval('mymes.actions_id_seq'::regclass);


--
-- TOC entry 3380 (class 2604 OID 17017)
-- Name: availabilities id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.availabilities ALTER COLUMN id SET DEFAULT nextval('mymes.availabilities_id_seq'::regclass);


--
-- TOC entry 3379 (class 2604 OID 16957)
-- Name: availability_profiles id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.availability_profiles ALTER COLUMN id SET DEFAULT nextval('mymes.availability_profile_id_seq'::regclass);


--
-- TOC entry 3402 (class 2604 OID 25371)
-- Name: bom id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.bom ALTER COLUMN id SET DEFAULT nextval('mymes.bom_id_seq'::regclass);


--
-- TOC entry 3360 (class 2604 OID 16839)
-- Name: departments id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.departments ALTER COLUMN id SET DEFAULT nextval('mymes.departments_id_seq'::regclass);


--
-- TOC entry 3367 (class 2604 OID 16929)
-- Name: employees id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees ALTER COLUMN id SET DEFAULT nextval('mymes.resources_id_seq'::regclass);


--
-- TOC entry 3368 (class 2604 OID 16975)
-- Name: employees level; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees ALTER COLUMN level SET DEFAULT 0;


--
-- TOC entry 3369 (class 2604 OID 17062)
-- Name: employees tags; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees ALTER COLUMN tags SET DEFAULT ARRAY[]::text[];


--
-- TOC entry 3373 (class 2604 OID 16933)
-- Name: equipments id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.equipments ALTER COLUMN id SET DEFAULT nextval('mymes.resources_id_seq'::regclass);


--
-- TOC entry 3374 (class 2604 OID 16976)
-- Name: equipments level; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.equipments ALTER COLUMN level SET DEFAULT 0;


--
-- TOC entry 3375 (class 2604 OID 17063)
-- Name: equipments tags; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.equipments ALTER COLUMN tags SET DEFAULT ARRAY[]::text[];


--
-- TOC entry 3423 (class 2604 OID 27491)
-- Name: event_triggers id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.event_triggers ALTER COLUMN id SET DEFAULT nextval('mymes.checks_id_seq'::regclass);


--
-- TOC entry 3415 (class 2604 OID 26839)
-- Name: fault id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault ALTER COLUMN id SET DEFAULT nextval('mymes.malf_id_seq'::regclass);


--
-- TOC entry 3414 (class 2604 OID 26545)
-- Name: fault_status id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_status ALTER COLUMN id SET DEFAULT nextval('mymes.malf_status_id_seq'::regclass);


--
-- TOC entry 3413 (class 2604 OID 26521)
-- Name: fault_type id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_type ALTER COLUMN id SET DEFAULT nextval('mymes.malf_type_id_seq'::regclass);


--
-- TOC entry 3418 (class 2604 OID 27289)
-- Name: fault_type_act id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_type_act ALTER COLUMN id SET DEFAULT nextval('mymes.fault_type_act_id_seq'::regclass);


--
-- TOC entry 3419 (class 2604 OID 27344)
-- Name: fix id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix ALTER COLUMN id SET DEFAULT nextval('mymes.fix_id_seq'::regclass);


--
-- TOC entry 3421 (class 2604 OID 27386)
-- Name: fix_act id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix_act ALTER COLUMN id SET DEFAULT nextval('mymes.fix_act_id_seq'::regclass);


--
-- TOC entry 3420 (class 2604 OID 27359)
-- Name: fix_t fix_id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix_t ALTER COLUMN fix_id SET DEFAULT nextval('mymes.fix_t_fix_id_seq'::regclass);


--
-- TOC entry 3405 (class 2604 OID 25481)
-- Name: identifier id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.identifier ALTER COLUMN id SET DEFAULT nextval('mymes.identifiers_id_seq'::regclass);


--
-- TOC entry 3397 (class 2604 OID 25240)
-- Name: import_schemas id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.import_schemas ALTER COLUMN id SET DEFAULT nextval('mymes.import_schemas_id_seq'::regclass);


--
-- TOC entry 3396 (class 2604 OID 26741)
-- Name: kit id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.kit ALTER COLUMN id SET DEFAULT nextval('mymes.kit_id_seq'::regclass);


--
-- TOC entry 3357 (class 2604 OID 16536)
-- Name: languages id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.languages ALTER COLUMN id SET DEFAULT nextval('mymes."serial_seq_LANGUAGES_LANG"'::regclass);


--
-- TOC entry 3403 (class 2604 OID 25413)
-- Name: local_actions id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.local_actions ALTER COLUMN id SET DEFAULT nextval('mymes.local_actions_id_seq'::regclass);


--
-- TOC entry 3394 (class 2604 OID 26731)
-- Name: locations id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.locations ALTER COLUMN id SET DEFAULT nextval('mymes.locations_id_seq'::regclass);


--
-- TOC entry 3422 (class 2604 OID 27468)
-- Name: lot_swap id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.lot_swap ALTER COLUMN id SET DEFAULT nextval('mymes.lot_swap_id_seq'::regclass);


--
-- TOC entry 3386 (class 2604 OID 17110)
-- Name: malfunction_types id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.malfunction_types ALTER COLUMN id SET DEFAULT nextval('mymes.malfunction_types_id_seq'::regclass);


--
-- TOC entry 3384 (class 2604 OID 17080)
-- Name: malfunctions id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.malfunctions ALTER COLUMN id SET DEFAULT nextval('mymes.malfunctions_id_seq'::regclass);


--
-- TOC entry 3391 (class 2604 OID 17198)
-- Name: mnt_plan_items id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.mnt_plan_items ALTER COLUMN id SET DEFAULT nextval('mymes.mnt_plan_items_id_seq'::regclass);


--
-- TOC entry 3390 (class 2604 OID 17181)
-- Name: mnt_plans id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.mnt_plans ALTER COLUMN id SET DEFAULT nextval('mymes.mnt_plan_id_seq'::regclass);


--
-- TOC entry 3409 (class 2604 OID 25585)
-- Name: notifications id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.notifications ALTER COLUMN id SET DEFAULT nextval('mymes.notifications_id_seq'::regclass);


--
-- TOC entry 3417 (class 2604 OID 27035)
-- Name: numerators id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.numerators ALTER COLUMN id SET DEFAULT nextval('mymes.numerators_id_seq'::regclass);


--
-- TOC entry 3361 (class 2604 OID 16871)
-- Name: part id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part ALTER COLUMN id SET DEFAULT nextval('mymes.part_id_seq'::regclass);


--
-- TOC entry 3363 (class 2604 OID 16891)
-- Name: part_status id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part_status ALTER COLUMN id SET DEFAULT nextval('mymes.part_status_id_seq'::regclass);


--
-- TOC entry 3359 (class 2604 OID 16699)
-- Name: permissions id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.permissions ALTER COLUMN id SET DEFAULT nextval('mymes."PERMISSIONS_PERMISION_seq"'::regclass);


--
-- TOC entry 3411 (class 2604 OID 26354)
-- Name: positions id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.positions ALTER COLUMN id SET DEFAULT nextval('mymes.positions_id_seq'::regclass);


--
-- TOC entry 3407 (class 2604 OID 25500)
-- Name: preferences id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.preferences ALTER COLUMN id SET DEFAULT nextval('mymes.preferences_id_seq'::regclass);


--
-- TOC entry 3400 (class 2604 OID 25330)
-- Name: proc_act id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.proc_act ALTER COLUMN id SET DEFAULT nextval('mymes.proc_act_id_seq'::regclass);


--
-- TOC entry 3399 (class 2604 OID 25307)
-- Name: process id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.process ALTER COLUMN id SET DEFAULT nextval('mymes.process_id_seq'::regclass);


--
-- TOC entry 3389 (class 2604 OID 17164)
-- Name: repair_types id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.repair_types ALTER COLUMN id SET DEFAULT nextval('mymes.repair_types_id_seq'::regclass);


--
-- TOC entry 3388 (class 2604 OID 17153)
-- Name: repairs id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.repairs ALTER COLUMN id SET DEFAULT nextval('mymes.repairs_id_seq'::regclass);


--
-- TOC entry 3410 (class 2604 OID 26340)
-- Name: resource_arc id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_arc ALTER COLUMN id SET DEFAULT nextval('mymes.resource_arc_id_seq'::regclass);


--
-- TOC entry 3376 (class 2604 OID 16948)
-- Name: resource_groups id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_groups ALTER COLUMN id SET DEFAULT nextval('mymes.resources_id_seq'::regclass);


--
-- TOC entry 3377 (class 2604 OID 16977)
-- Name: resource_groups level; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_groups ALTER COLUMN level SET DEFAULT 0;


--
-- TOC entry 3378 (class 2604 OID 17064)
-- Name: resource_groups tags; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_groups ALTER COLUMN tags SET DEFAULT ARRAY[]::text[];


--
-- TOC entry 3408 (class 2604 OID 25531)
-- Name: resource_timeoff id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_timeoff ALTER COLUMN id SET DEFAULT nextval('mymes.ap_holidays_id_seq'::regclass);


--
-- TOC entry 3364 (class 2604 OID 16923)
-- Name: resources id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resources ALTER COLUMN id SET DEFAULT nextval('mymes.resources_id_seq'::regclass);


--
-- TOC entry 3401 (class 2604 OID 25346)
-- Name: serial_act id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serial_act ALTER COLUMN id SET DEFAULT nextval('mymes.serial_act_id_seq'::regclass);


--
-- TOC entry 3398 (class 2604 OID 25259)
-- Name: serial_statuses id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serial_statuses ALTER COLUMN id SET DEFAULT nextval('mymes.serial_statuses_id_seq'::regclass);


--
-- TOC entry 3393 (class 2604 OID 25188)
-- Name: serials id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials ALTER COLUMN id SET DEFAULT nextval('mymes.serials_id_seq'::regclass);


--
-- TOC entry 3382 (class 2604 OID 17029)
-- Name: standards id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.standards ALTER COLUMN id SET DEFAULT nextval('mymes.standards_id_seq'::regclass);


--
-- TOC entry 3383 (class 2604 OID 17040)
-- Name: standards_types id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.standards_types ALTER COLUMN id SET DEFAULT nextval('mymes.standards_types_id_seq'::regclass);


--
-- TOC entry 3424 (class 2604 OID 27539)
-- Name: tables id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.tables ALTER COLUMN id SET DEFAULT nextval('mymes.tables_id_seq'::regclass);


--
-- TOC entry 3404 (class 2604 OID 26823)
-- Name: work_report id; Type: DEFAULT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.work_report ALTER COLUMN id SET DEFAULT nextval('mymes.work_report_id_seq'::regclass);


--
-- TOC entry 3392 (class 2604 OID 17232)
-- Name: bugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bugs ALTER COLUMN id SET DEFAULT nextval('public.bugs_id_seq'::regclass);


--
-- TOC entry 3387 (class 2604 OID 17138)
-- Name: profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles ALTER COLUMN id SET DEFAULT nextval('public.profiles_id_seq'::regclass);


--
-- TOC entry 3358 (class 2604 OID 16525)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public."USERS_USERID_seq"'::regclass);


--
-- TOC entry 3485 (class 2606 OID 16973)
-- Name:  utilization  utilization_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes." utilization"
    ADD CONSTRAINT " utilization_pkey" PRIMARY KEY (id);


--
-- TOC entry 3426 (class 2606 OID 16816)
-- Name: languages LANGUAGES_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.languages
    ADD CONSTRAINT "LANGUAGES_pkey" PRIMARY KEY (id);


--
-- TOC entry 3428 (class 2606 OID 16814)
-- Name: languages LANG_NAME_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.languages
    ADD CONSTRAINT "LANG_NAME_key" UNIQUE (name);


--
-- TOC entry 3435 (class 2606 OID 16801)
-- Name: permissions PERMISSIONS_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.permissions
    ADD CONSTRAINT "PERMISSIONS_pkey" PRIMARY KEY (id);


--
-- TOC entry 3437 (class 2606 OID 16778)
-- Name: resource_groups_t RESOURCES_T_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_groups_t
    ADD CONSTRAINT "RESOURCES_T_pkey" PRIMARY KEY (lang_id, resource_group_id);


--
-- TOC entry 3587 (class 2606 OID 26397)
-- Name: act_resources act_resources_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.act_resources
    ADD CONSTRAINT act_resources_pkey PRIMARY KEY (act_id, resource_id, type);


--
-- TOC entry 3589 (class 2606 OID 26402)
-- Name: act_resources act_resources_resource_id_act_id_type_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.act_resources
    ADD CONSTRAINT act_resources_resource_id_act_id_type_key UNIQUE (resource_id, act_id, type);


--
-- TOC entry 3518 (class 2606 OID 26433)
-- Name: actions actions_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.actions
    ADD CONSTRAINT actions_name_key UNIQUE (name);


--
-- TOC entry 3520 (class 2606 OID 25215)
-- Name: actions actions_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (id);


--
-- TOC entry 3522 (class 2606 OID 25223)
-- Name: actions_t actions_t_action_id_lang_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.actions_t
    ADD CONSTRAINT actions_t_action_id_lang_id_key UNIQUE (action_id, lang_id);


--
-- TOC entry 3575 (class 2606 OID 25533)
-- Name: resource_timeoff ap_holidays_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_timeoff
    ADD CONSTRAINT ap_holidays_pkey PRIMARY KEY (id);


--
-- TOC entry 3483 (class 2606 OID 25422)
-- Name: availabilities availabilities_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.availabilities
    ADD CONSTRAINT availabilities_pkey PRIMARY KEY (id);


--
-- TOC entry 3481 (class 2606 OID 16959)
-- Name: availability_profiles availability_profile_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.availability_profiles
    ADD CONSTRAINT availability_profile_pkey PRIMARY KEY (id);


--
-- TOC entry 3487 (class 2606 OID 17005)
-- Name: availability_profiles_t availability_profile_t_ap_id_land_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.availability_profiles_t
    ADD CONSTRAINT availability_profile_t_ap_id_land_id_key UNIQUE (ap_id, lang_id);


--
-- TOC entry 3557 (class 2606 OID 25376)
-- Name: bom bom_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.bom
    ADD CONSTRAINT bom_pkey PRIMARY KEY (id);


--
-- TOC entry 3634 (class 2606 OID 27496)
-- Name: event_triggers checks_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.event_triggers
    ADD CONSTRAINT checks_pkey PRIMARY KEY (id);


--
-- TOC entry 3445 (class 2606 OID 16865)
-- Name: configurations configurations_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.configurations
    ADD CONSTRAINT configurations_pkey PRIMARY KEY (key);


--
-- TOC entry 3591 (class 2606 OID 26509)
-- Name: convers convers_id_row_type_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.convers
    ADD CONSTRAINT convers_id_row_type_key UNIQUE (id, row_type);


--
-- TOC entry 3441 (class 2606 OID 17223)
-- Name: departments departments_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.departments
    ADD CONSTRAINT departments_name_key UNIQUE (name);


--
-- TOC entry 3443 (class 2606 OID 16841)
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- TOC entry 3439 (class 2606 OID 16903)
-- Name: departments_t departments_t_dept_id_lang_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.departments_t
    ADD CONSTRAINT departments_t_dept_id_lang_id_key UNIQUE (dept_id, lang_id);


--
-- TOC entry 3463 (class 2606 OID 25900)
-- Name: employees employees_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_id_key UNIQUE (id);


--
-- TOC entry 3465 (class 2606 OID 26298)
-- Name: employees employees_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_name_key UNIQUE (name);


--
-- TOC entry 3467 (class 2606 OID 26075)
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- TOC entry 3469 (class 2606 OID 25907)
-- Name: equipments equipments_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.equipments
    ADD CONSTRAINT equipments_id_key UNIQUE (id);


--
-- TOC entry 3471 (class 2606 OID 26296)
-- Name: equipments equipments_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.equipments
    ADD CONSTRAINT equipments_name_key UNIQUE (name);


--
-- TOC entry 3473 (class 2606 OID 26043)
-- Name: equipments equipments_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.equipments
    ADD CONSTRAINT equipments_pkey PRIMARY KEY (id);


--
-- TOC entry 3636 (class 2606 OID 35677)
-- Name: event_triggers event_triggers_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.event_triggers
    ADD CONSTRAINT event_triggers_name_key UNIQUE (name);


--
-- TOC entry 3603 (class 2606 OID 26860)
-- Name: fault fault_id_row_type_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_id_row_type_key UNIQUE (id, row_type);


--
-- TOC entry 3605 (class 2606 OID 26841)
-- Name: fault fault_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_pkey PRIMARY KEY (id);


--
-- TOC entry 3618 (class 2606 OID 27285)
-- Name: fault_type_act fault_type_act_fault_type_id_act_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_type_act
    ADD CONSTRAINT fault_type_act_fault_type_id_act_id_key UNIQUE (fault_type_id, action_id);


--
-- TOC entry 3620 (class 2606 OID 27380)
-- Name: fault_type_act fault_type_act_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_type_act
    ADD CONSTRAINT fault_type_act_pkey PRIMARY KEY (id);


--
-- TOC entry 3593 (class 2606 OID 27264)
-- Name: fault_type fault_type_extname_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_type
    ADD CONSTRAINT fault_type_extname_key UNIQUE (extname);


--
-- TOC entry 3628 (class 2606 OID 27390)
-- Name: fix_act fix_act_fix_id_action_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix_act
    ADD CONSTRAINT fix_act_fix_id_action_id_key UNIQUE (fix_id, action_id);


--
-- TOC entry 3630 (class 2606 OID 27388)
-- Name: fix_act fix_act_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix_act
    ADD CONSTRAINT fix_act_pkey PRIMARY KEY (id);


--
-- TOC entry 3622 (class 2606 OID 27351)
-- Name: fix fix_extname_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix
    ADD CONSTRAINT fix_extname_key UNIQUE (extname);


--
-- TOC entry 3624 (class 2606 OID 27353)
-- Name: fix fix_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix
    ADD CONSTRAINT fix_name_key UNIQUE (name);


--
-- TOC entry 3626 (class 2606 OID 27349)
-- Name: fix fix_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix
    ADD CONSTRAINT fix_pkey PRIMARY KEY (id);


--
-- TOC entry 3607 (class 2606 OID 26869)
-- Name: sendable identifiable_id_row_type_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.sendable
    ADD CONSTRAINT identifiable_id_row_type_key UNIQUE (id, row_type);


--
-- TOC entry 3609 (class 2606 OID 26833)
-- Name: sendable identifiable_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.sendable
    ADD CONSTRAINT identifiable_pkey PRIMARY KEY (id);


--
-- TOC entry 3569 (class 2606 OID 26999)
-- Name: identifier identifier_name_parent_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.identifier
    ADD CONSTRAINT identifier_name_parent_id_key UNIQUE (name, parent_id);


--
-- TOC entry 3571 (class 2606 OID 25486)
-- Name: identifier identifiers_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.identifier
    ADD CONSTRAINT identifiers_pkey PRIMARY KEY (id);


--
-- TOC entry 3530 (class 2606 OID 25253)
-- Name: import_schamas_t import_schamas_t_import_schama_id_lang_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.import_schamas_t
    ADD CONSTRAINT import_schamas_t_import_schama_id_lang_id_key UNIQUE (import_schama_id, lang_id);


--
-- TOC entry 3528 (class 2606 OID 25245)
-- Name: import_schemas import_schemas_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.import_schemas
    ADD CONSTRAINT import_schemas_pkey PRIMARY KEY (id);


--
-- TOC entry 3524 (class 2606 OID 26743)
-- Name: kit kit_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.kit
    ADD CONSTRAINT kit_pkey PRIMARY KEY (id);


--
-- TOC entry 3526 (class 2606 OID 25234)
-- Name: kit kit_serial_partname_lot_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.kit
    ADD CONSTRAINT kit_serial_partname_lot_key UNIQUE (serial_id, partname, lot);


--
-- TOC entry 3632 (class 2606 OID 27453)
-- Name: kit_usage kit_usage_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.kit_usage
    ADD CONSTRAINT kit_usage_pkey PRIMARY KEY (start_date, kit_id);


--
-- TOC entry 3559 (class 2606 OID 25420)
-- Name: local_actions local_actions_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.local_actions
    ADD CONSTRAINT local_actions_name_key UNIQUE (name);


--
-- TOC entry 3561 (class 2606 OID 25418)
-- Name: local_actions local_actions_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.local_actions
    ADD CONSTRAINT local_actions_pkey PRIMARY KEY (id);


--
-- TOC entry 3563 (class 2606 OID 25438)
-- Name: local_actions_t local_actions_t_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.local_actions_t
    ADD CONSTRAINT local_actions_t_pkey PRIMARY KEY (local_action_id, lang_id);


--
-- TOC entry 3516 (class 2606 OID 26733)
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- TOC entry 3599 (class 2606 OID 26552)
-- Name: fault_status malf_status_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_status
    ADD CONSTRAINT malf_status_name_key UNIQUE (name);


--
-- TOC entry 3601 (class 2606 OID 26550)
-- Name: fault_status malf_status_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_status
    ADD CONSTRAINT malf_status_pkey PRIMARY KEY (id);


--
-- TOC entry 3595 (class 2606 OID 26526)
-- Name: fault_type malf_type_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_type
    ADD CONSTRAINT malf_type_name_key UNIQUE (name);


--
-- TOC entry 3597 (class 2606 OID 26554)
-- Name: fault_type malf_type_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_type
    ADD CONSTRAINT malf_type_pkey PRIMARY KEY (id);


--
-- TOC entry 3495 (class 2606 OID 17115)
-- Name: malfunction_types malfunction_types_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.malfunction_types
    ADD CONSTRAINT malfunction_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3493 (class 2606 OID 17085)
-- Name: malfunctions malfunctions_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.malfunctions
    ADD CONSTRAINT malfunctions_pkey PRIMARY KEY (id);


--
-- TOC entry 3497 (class 2606 OID 17120)
-- Name: malfunctions_t malfunctions_t_malfunction_id_lang_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.malfunctions_t
    ADD CONSTRAINT malfunctions_t_malfunction_id_lang_id_key UNIQUE (malfunction_id, lang_id);


--
-- TOC entry 3505 (class 2606 OID 17203)
-- Name: mnt_plan_items mnt_plan_items_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.mnt_plan_items
    ADD CONSTRAINT mnt_plan_items_pkey PRIMARY KEY (id);


--
-- TOC entry 3503 (class 2606 OID 17186)
-- Name: mnt_plans mnt_plan_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.mnt_plans
    ADD CONSTRAINT mnt_plan_pkey PRIMARY KEY (id);


--
-- TOC entry 3577 (class 2606 OID 25590)
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 3612 (class 2606 OID 27043)
-- Name: numerators numerators_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.numerators
    ADD CONSTRAINT numerators_pkey PRIMARY KEY (id);


--
-- TOC entry 3614 (class 2606 OID 27051)
-- Name: numerators numerators_prefix_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.numerators
    ADD CONSTRAINT numerators_prefix_key UNIQUE (prefix);


--
-- TOC entry 3616 (class 2606 OID 27049)
-- Name: numerators numerators_row_type_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.numerators
    ADD CONSTRAINT numerators_row_type_key UNIQUE (row_type);


--
-- TOC entry 3447 (class 2606 OID 26114)
-- Name: part part_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part
    ADD CONSTRAINT part_id_key UNIQUE (id);


--
-- TOC entry 3449 (class 2606 OID 26442)
-- Name: part part_name_revision_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part
    ADD CONSTRAINT part_name_revision_key UNIQUE (name, revision);


--
-- TOC entry 3451 (class 2606 OID 16873)
-- Name: part part_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part
    ADD CONSTRAINT part_pkey PRIMARY KEY (id);


--
-- TOC entry 3453 (class 2606 OID 16893)
-- Name: part_status part_status_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part_status
    ADD CONSTRAINT part_status_pkey PRIMARY KEY (id);


--
-- TOC entry 3455 (class 2606 OID 16901)
-- Name: part_status_t part_status_t_part_status_id_lang_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part_status_t
    ADD CONSTRAINT part_status_t_part_status_id_lang_id_key UNIQUE (part_status_id, lang_id);


--
-- TOC entry 3583 (class 2606 OID 26359)
-- Name: positions positions_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);


--
-- TOC entry 3585 (class 2606 OID 26367)
-- Name: positions_t positions_t_position_id_lang_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.positions_t
    ADD CONSTRAINT positions_t_position_id_lang_id_key UNIQUE (position_id, lang_id);


--
-- TOC entry 3573 (class 2606 OID 26205)
-- Name: preferences preferences_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.preferences
    ADD CONSTRAINT preferences_name_key UNIQUE (name);


--
-- TOC entry 3544 (class 2606 OID 25332)
-- Name: proc_act proc_act_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_pkey PRIMARY KEY (id);


--
-- TOC entry 3546 (class 2606 OID 25334)
-- Name: proc_act proc_act_process_id_act_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_process_id_act_id_key UNIQUE (process_id, act_id);


--
-- TOC entry 3548 (class 2606 OID 25336)
-- Name: proc_act proc_act_process_id_pos_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_process_id_pos_key UNIQUE (process_id, pos);


--
-- TOC entry 3538 (class 2606 OID 26444)
-- Name: process process_erpproc_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.process
    ADD CONSTRAINT process_erpproc_key UNIQUE (erpproc);


--
-- TOC entry 3540 (class 2606 OID 25314)
-- Name: process process_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.process
    ADD CONSTRAINT process_name_key UNIQUE (name);


--
-- TOC entry 3542 (class 2606 OID 25312)
-- Name: process process_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.process
    ADD CONSTRAINT process_pkey PRIMARY KEY (id);


--
-- TOC entry 3501 (class 2606 OID 17169)
-- Name: repair_types repair_types_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.repair_types
    ADD CONSTRAINT repair_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3499 (class 2606 OID 17158)
-- Name: repairs repairs_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.repairs
    ADD CONSTRAINT repairs_pkey PRIMARY KEY (id);


--
-- TOC entry 3579 (class 2606 OID 26345)
-- Name: resource_arc resource_arc_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_arc
    ADD CONSTRAINT resource_arc_pkey PRIMARY KEY (id);


--
-- TOC entry 3581 (class 2606 OID 26347)
-- Name: resource_arc resource_arc_son_id_parent_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_arc
    ADD CONSTRAINT resource_arc_son_id_parent_id_key UNIQUE (son_id, parent_id);


--
-- TOC entry 3475 (class 2606 OID 25969)
-- Name: resource_groups resource_groups_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_groups
    ADD CONSTRAINT resource_groups_id_key UNIQUE (id);


--
-- TOC entry 3477 (class 2606 OID 26300)
-- Name: resource_groups resource_groups_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_groups
    ADD CONSTRAINT resource_groups_name_key UNIQUE (name);


--
-- TOC entry 3479 (class 2606 OID 26077)
-- Name: resource_groups resource_groups_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_groups
    ADD CONSTRAINT resource_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 3457 (class 2606 OID 25898)
-- Name: resources resources_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resources
    ADD CONSTRAINT resources_id_key UNIQUE (id);


--
-- TOC entry 3459 (class 2606 OID 26294)
-- Name: resources resources_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resources
    ADD CONSTRAINT resources_name_key UNIQUE (name);


--
-- TOC entry 3461 (class 2606 OID 16925)
-- Name: resources resources_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resources
    ADD CONSTRAINT resources_pkey PRIMARY KEY (id);


--
-- TOC entry 3550 (class 2606 OID 25348)
-- Name: serial_act serial_act_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serial_act
    ADD CONSTRAINT serial_act_pkey PRIMARY KEY (id);


--
-- TOC entry 3552 (class 2606 OID 25350)
-- Name: serial_act serial_act_serial_id_act_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serial_act
    ADD CONSTRAINT serial_act_serial_id_act_id_key UNIQUE (serial_id, act_id);


--
-- TOC entry 3554 (class 2606 OID 25352)
-- Name: serial_act serial_act_serial_id_pos_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serial_act
    ADD CONSTRAINT serial_act_serial_id_pos_key UNIQUE (serial_id, pos);


--
-- TOC entry 3532 (class 2606 OID 25981)
-- Name: serial_statuses serial_statuses_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serial_statuses
    ADD CONSTRAINT serial_statuses_pkey PRIMARY KEY (id);


--
-- TOC entry 3534 (class 2606 OID 25270)
-- Name: serial_statuses_t serial_statuses_t_serial_id_lang_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serial_statuses_t
    ADD CONSTRAINT serial_statuses_t_serial_id_lang_id_key UNIQUE (serial_status_id, lang_id);


--
-- TOC entry 3509 (class 2606 OID 25602)
-- Name: serials serials_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_id_key UNIQUE (id);


--
-- TOC entry 3511 (class 2606 OID 26435)
-- Name: serials serials_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_name_key UNIQUE (name);


--
-- TOC entry 3513 (class 2606 OID 25600)
-- Name: serials serials_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_pkey PRIMARY KEY (id);


--
-- TOC entry 3536 (class 2606 OID 25278)
-- Name: serials_t serials_t_serial_id_lang_id_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials_t
    ADD CONSTRAINT serials_t_serial_id_lang_id_key UNIQUE (serial_id, lang_id);


--
-- TOC entry 3489 (class 2606 OID 17034)
-- Name: standards standards_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.standards
    ADD CONSTRAINT standards_pkey PRIMARY KEY (id);


--
-- TOC entry 3491 (class 2606 OID 17045)
-- Name: standards_types standards_types_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.standards_types
    ADD CONSTRAINT standards_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3640 (class 2606 OID 27546)
-- Name: tables tables_name_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.tables
    ADD CONSTRAINT tables_name_key UNIQUE (name);


--
-- TOC entry 3642 (class 2606 OID 27544)
-- Name: tables tables_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.tables
    ADD CONSTRAINT tables_pkey PRIMARY KEY (id);


--
-- TOC entry 3565 (class 2606 OID 26867)
-- Name: work_report work_report_id_row_type_key; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_id_row_type_key UNIQUE (id, row_type);


--
-- TOC entry 3567 (class 2606 OID 26825)
-- Name: work_report work_report_pkey; Type: CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_pkey PRIMARY KEY (id);


--
-- TOC entry 3431 (class 2606 OID 16770)
-- Name: users USERS_USERNAME_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT "USERS_USERNAME_key" UNIQUE (username);


--
-- TOC entry 3433 (class 2606 OID 16772)
-- Name: users USERS_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT "USERS_pkey" PRIMARY KEY (id);


--
-- TOC entry 3507 (class 2606 OID 17237)
-- Name: bugs bugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bugs
    ADD CONSTRAINT bugs_pkey PRIMARY KEY (id);


--
-- TOC entry 3638 (class 2606 OID 27530)
-- Name: condition_type condition_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.condition_type
    ADD CONSTRAINT condition_type_pkey PRIMARY KEY (condition);


--
-- TOC entry 3555 (class 1259 OID 27275)
-- Name: BOM_part_id_partname; Type: INDEX; Schema: mymes; Owner: -
--

CREATE INDEX "BOM_part_id_partname" ON mymes.bom USING btree (parent_id, partname);


--
-- TOC entry 3514 (class 1259 OID 27274)
-- Name: LOCATIONS_part_id_partname; Type: INDEX; Schema: mymes; Owner: -
--

CREATE INDEX "LOCATIONS_part_id_partname" ON mymes.locations USING btree (part_id, partname);


--
-- TOC entry 3610 (class 1259 OID 27310)
-- Name: unique_index_identifier_links; Type: INDEX; Schema: mymes; Owner: -
--

CREATE UNIQUE INDEX unique_index_identifier_links ON mymes.identifier_links USING btree (identifier_id, serial_id, act_id) WHERE (row_type = 'work_report'::public.row_type);


--
-- TOC entry 3429 (class 1259 OID 16773)
-- Name: USERNAME; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "USERNAME" ON public.users USING btree (username);


--
-- TOC entry 3904 (class 2618 OID 27062)
-- Name: numerators numerators_del_protect; Type: RULE; Schema: mymes; Owner: -
--

CREATE RULE numerators_del_protect AS
    ON DELETE TO mymes.numerators DO INSTEAD NOTHING;


--
-- TOC entry 3905 (class 2618 OID 27063)
-- Name: preferences preferences_del_protect; Type: RULE; Schema: mymes; Owner: -
--

CREATE RULE preferences_del_protect AS
    ON DELETE TO mymes.preferences DO INSTEAD NOTHING;


--
-- TOC entry 3745 (class 2620 OID 35700)
-- Name: process events_trigger; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger AFTER UPDATE ON mymes.process FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3740 (class 2620 OID 35714)
-- Name: actions events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.actions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3730 (class 2620 OID 35715)
-- Name: serials events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.serials FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3746 (class 2620 OID 35718)
-- Name: bom events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.bom FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3741 (class 2620 OID 35721)
-- Name: kit events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.kit FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3716 (class 2620 OID 35724)
-- Name: availability_profiles events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.availability_profiles FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3709 (class 2620 OID 35727)
-- Name: employees events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.employees FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3712 (class 2620 OID 35730)
-- Name: equipments events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.equipments FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3773 (class 2620 OID 35733)
-- Name: fault events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3703 (class 2620 OID 35736)
-- Name: part events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3753 (class 2620 OID 35739)
-- Name: work_report events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3759 (class 2620 OID 35742)
-- Name: identifier events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3734 (class 2620 OID 35745)
-- Name: locations events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.locations FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3720 (class 2620 OID 35748)
-- Name: malfunctions events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.malfunctions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3727 (class 2620 OID 35751)
-- Name: mnt_plans events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.mnt_plans FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3763 (class 2620 OID 35754)
-- Name: positions events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.positions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3723 (class 2620 OID 35757)
-- Name: repairs events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.repairs FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3706 (class 2620 OID 35760)
-- Name: resources events_trigger_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.resources FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();


--
-- TOC entry 3739 (class 2620 OID 35713)
-- Name: actions events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.actions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3731 (class 2620 OID 35716)
-- Name: serials events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.serials FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3747 (class 2620 OID 35719)
-- Name: bom events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.bom FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3742 (class 2620 OID 35722)
-- Name: kit events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.kit FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3717 (class 2620 OID 35725)
-- Name: availability_profiles events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.availability_profiles FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3710 (class 2620 OID 35728)
-- Name: employees events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.employees FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3714 (class 2620 OID 35731)
-- Name: equipments events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.equipments FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3774 (class 2620 OID 35734)
-- Name: fault events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3704 (class 2620 OID 35737)
-- Name: part events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3754 (class 2620 OID 35740)
-- Name: work_report events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3760 (class 2620 OID 35743)
-- Name: identifier events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3735 (class 2620 OID 35746)
-- Name: locations events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.locations FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3721 (class 2620 OID 35749)
-- Name: malfunctions events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.malfunctions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3728 (class 2620 OID 35752)
-- Name: mnt_plans events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.mnt_plans FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3764 (class 2620 OID 35755)
-- Name: positions events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.positions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3724 (class 2620 OID 35758)
-- Name: repairs events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.repairs FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3707 (class 2620 OID 35761)
-- Name: resources events_trigger_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.resources FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();


--
-- TOC entry 3738 (class 2620 OID 35712)
-- Name: actions events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.actions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3732 (class 2620 OID 35717)
-- Name: serials events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.serials FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3748 (class 2620 OID 35720)
-- Name: bom events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.bom FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3743 (class 2620 OID 35723)
-- Name: kit events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.kit FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3718 (class 2620 OID 35726)
-- Name: availability_profiles events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.availability_profiles FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3711 (class 2620 OID 35729)
-- Name: employees events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.employees FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3715 (class 2620 OID 35732)
-- Name: equipments events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.equipments FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3775 (class 2620 OID 35735)
-- Name: fault events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3705 (class 2620 OID 35738)
-- Name: part events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3755 (class 2620 OID 35741)
-- Name: work_report events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3761 (class 2620 OID 35744)
-- Name: identifier events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3736 (class 2620 OID 35747)
-- Name: locations events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.locations FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3722 (class 2620 OID 35750)
-- Name: malfunctions events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.malfunctions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3729 (class 2620 OID 35753)
-- Name: mnt_plans events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.mnt_plans FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3765 (class 2620 OID 35756)
-- Name: positions events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.positions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3725 (class 2620 OID 35759)
-- Name: repairs events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.repairs FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3708 (class 2620 OID 35762)
-- Name: resources events_trigger_update; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.resources FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();


--
-- TOC entry 3771 (class 2620 OID 26974)
-- Name: fault notify_fault; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER notify_fault AFTER INSERT ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.fault_notify();


--
-- TOC entry 3757 (class 2620 OID 27403)
-- Name: identifier post_delete; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER post_delete AFTER DELETE ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.post_delete_identifier();


--
-- TOC entry 3778 (class 2620 OID 27433)
-- Name: identifier_links post_insert; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER post_insert AFTER INSERT ON mymes.identifier_links FOR EACH ROW EXECUTE PROCEDURE public.post_insert_identifier_link();


--
-- TOC entry 3762 (class 2620 OID 26486)
-- Name: notifications post_insert_notify; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER post_insert_notify AFTER INSERT ON mymes.notifications FOR EACH ROW EXECUTE PROCEDURE public.mes_notify('notifications');


--
-- TOC entry 3769 (class 2620 OID 26906)
-- Name: fault pre_delete_Identifiable; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER "pre_delete_Identifiable" BEFORE DELETE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_sendable();


--
-- TOC entry 3751 (class 2620 OID 27482)
-- Name: work_report pre_delete_approved; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER pre_delete_approved BEFORE DELETE ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_approved();


--
-- TOC entry 3768 (class 2620 OID 27483)
-- Name: fault pre_delete_approved; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER pre_delete_approved BEFORE DELETE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_approved();


--
-- TOC entry 3777 (class 2620 OID 27485)
-- Name: identifier_links pre_delete_approved; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER pre_delete_approved BEFORE DELETE ON mymes.identifier_links FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_approved();


--
-- TOC entry 3776 (class 2620 OID 26904)
-- Name: sendable pre_delete_identifiable; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER pre_delete_identifiable BEFORE DELETE ON mymes.sendable FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_sendable();


--
-- TOC entry 3758 (class 2620 OID 26911)
-- Name: identifier pre_delete_identifier; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER pre_delete_identifier BEFORE DELETE ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_identifier();


--
-- TOC entry 3750 (class 2620 OID 26905)
-- Name: work_report pre_delete_sendable; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER pre_delete_sendable BEFORE DELETE ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_sendable();


--
-- TOC entry 3752 (class 2620 OID 27006)
-- Name: work_report pre_insert_balance_checks; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER pre_insert_balance_checks BEFORE INSERT ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.check_serial_act();


--
-- TOC entry 3756 (class 2620 OID 26964)
-- Name: identifier pre_insert_set_part_id; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER pre_insert_set_part_id BEFORE INSERT ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.pre_insert_identifier();


--
-- TOC entry 3772 (class 2620 OID 27309)
-- Name: fault set_fault_status; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_fault_status BEFORE INSERT OR UPDATE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.set_fault_status();


--
-- TOC entry 3770 (class 2620 OID 26944)
-- Name: fault set_name; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_name BEFORE INSERT ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.set_name();


--
-- TOC entry 3733 (class 2620 OID 27052)
-- Name: serials set_name; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_name BEFORE INSERT ON mymes.serials FOR EACH ROW EXECUTE PROCEDURE public.set_name();


--
-- TOC entry 3702 (class 2620 OID 27053)
-- Name: part set_name; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_name BEFORE INSERT ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.set_name();


--
-- TOC entry 3737 (class 2620 OID 27054)
-- Name: actions set_name; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_name BEFORE INSERT ON mymes.actions FOR EACH ROW EXECUTE PROCEDURE public.set_name();


--
-- TOC entry 3713 (class 2620 OID 27057)
-- Name: equipments set_name; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_name BEFORE INSERT ON mymes.equipments FOR EACH ROW EXECUTE PROCEDURE public.set_name();


--
-- TOC entry 3719 (class 2620 OID 27058)
-- Name: malfunctions set_name; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_name BEFORE INSERT ON mymes.malfunctions FOR EACH ROW EXECUTE PROCEDURE public.set_name();


--
-- TOC entry 3726 (class 2620 OID 27059)
-- Name: mnt_plans set_name; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_name BEFORE INSERT ON mymes.mnt_plans FOR EACH ROW EXECUTE PROCEDURE public.set_name();


--
-- TOC entry 3744 (class 2620 OID 27060)
-- Name: process set_name; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_name BEFORE INSERT ON mymes.process FOR EACH ROW EXECUTE PROCEDURE public.set_name();


--
-- TOC entry 3766 (class 2620 OID 27265)
-- Name: fault_type set_name; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_name BEFORE INSERT ON mymes.fault_type FOR EACH ROW EXECUTE PROCEDURE public.set_name();


--
-- TOC entry 3749 (class 2620 OID 27479)
-- Name: work_report set_sig_date; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_sig_date BEFORE INSERT ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_sig_date();


--
-- TOC entry 3767 (class 2620 OID 27480)
-- Name: fault set_sig_date; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_sig_date BEFORE INSERT ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_sig_date();


--
-- TOC entry 3701 (class 2620 OID 26987)
-- Name: part set_timestamp; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER set_timestamp BEFORE UPDATE ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_timestamp();


--
-- TOC entry 3779 (class 2620 OID 27462)
-- Name: lot_swap update_updated_at; Type: TRIGGER; Schema: mymes; Owner: -
--

CREATE TRIGGER update_updated_at BEFORE INSERT ON mymes.lot_swap FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_timestamp();


--
-- TOC entry 3675 (class 2606 OID 25847)
-- Name: actions_t actions_t_action_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.actions_t
    ADD CONSTRAINT actions_t_action_id_fkey FOREIGN KEY (action_id) REFERENCES mymes.actions(id) ON DELETE CASCADE;


--
-- TOC entry 3656 (class 2606 OID 25773)
-- Name: availabilities availabilities_availability_profile_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.availabilities
    ADD CONSTRAINT availabilities_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE CASCADE;


--
-- TOC entry 3657 (class 2606 OID 25887)
-- Name: availability_profiles_t availability_profiles_t_ap_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.availability_profiles_t
    ADD CONSTRAINT availability_profiles_t_ap_id_fkey FOREIGN KEY (ap_id) REFERENCES mymes.availability_profiles(id) ON DELETE CASCADE;


--
-- TOC entry 3684 (class 2606 OID 25992)
-- Name: bom bom_parent_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.bom
    ADD CONSTRAINT bom_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES mymes.part(id) ON DELETE RESTRICT;


--
-- TOC entry 3646 (class 2606 OID 25892)
-- Name: departments_t departments_t_dept_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.departments_t
    ADD CONSTRAINT departments_t_dept_id_fkey FOREIGN KEY (dept_id) REFERENCES mymes.departments(id) ON DELETE CASCADE;


--
-- TOC entry 3651 (class 2606 OID 26160)
-- Name: employees employees_availability_profile_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE RESTRICT;


--
-- TOC entry 3653 (class 2606 OID 26380)
-- Name: employees employees_position_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_position_id_fkey FOREIGN KEY (position_id) REFERENCES mymes.positions(id) ON DELETE RESTRICT;


--
-- TOC entry 3643 (class 2606 OID 25901)
-- Name: employees_t employees_t_emp_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees_t
    ADD CONSTRAINT employees_t_emp_id_fkey FOREIGN KEY (emp_id) REFERENCES mymes.employees(id) ON DELETE CASCADE;


--
-- TOC entry 3652 (class 2606 OID 26032)
-- Name: employees employees_user_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- TOC entry 3654 (class 2606 OID 26069)
-- Name: equipments equipments_availability_profile_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.equipments
    ADD CONSTRAINT equipments_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE RESTRICT;


--
-- TOC entry 3644 (class 2606 OID 25913)
-- Name: equipments_t equipments_t_equipment_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.equipments_t
    ADD CONSTRAINT equipments_t_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES mymes.equipments(id) ON DELETE CASCADE;


--
-- TOC entry 3693 (class 2606 OID 27404)
-- Name: fault fault_fix_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_fix_id_fkey FOREIGN KEY (fix_id) REFERENCES mymes.fix(id) ON DELETE RESTRICT;


--
-- TOC entry 3690 (class 2606 OID 26627)
-- Name: fault fault_serial_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE RESTRICT;


--
-- TOC entry 3691 (class 2606 OID 26632)
-- Name: fault fault_status_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_status_id_fkey FOREIGN KEY (fault_status_id) REFERENCES mymes.fault_status(id) ON DELETE RESTRICT;


--
-- TOC entry 3698 (class 2606 OID 27391)
-- Name: fault_type_act fault_type_act_fault_type_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_type_act
    ADD CONSTRAINT fault_type_act_fault_type_id_fkey FOREIGN KEY (fault_type_id) REFERENCES mymes.fault_type(id) ON DELETE RESTRICT;


--
-- TOC entry 3692 (class 2606 OID 26637)
-- Name: fault fault_type_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_type_id_fkey FOREIGN KEY (fault_type_id) REFERENCES mymes.fault_type(id) ON DELETE RESTRICT;


--
-- TOC entry 3700 (class 2606 OID 27396)
-- Name: fix_act fix_act_fix_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix_act
    ADD CONSTRAINT fix_act_fix_id_fkey FOREIGN KEY (fix_id) REFERENCES mymes.fix(id) ON DELETE RESTRICT;


--
-- TOC entry 3699 (class 2606 OID 27374)
-- Name: fix_t fix_t_fix_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fix_t
    ADD CONSTRAINT fix_t_fix_id_fkey FOREIGN KEY (fix_id) REFERENCES mymes.fix(id) ON DELETE CASCADE;


--
-- TOC entry 3697 (class 2606 OID 26806)
-- Name: identifier_links identifier_links_identifier_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.identifier_links
    ADD CONSTRAINT identifier_links_identifier_id_fkey FOREIGN KEY (identifier_id) REFERENCES mymes.identifier(id) ON DELETE CASCADE;


--
-- TOC entry 3689 (class 2606 OID 27299)
-- Name: identifier identifier_parent_identifier_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.identifier
    ADD CONSTRAINT identifier_parent_identifier_id_fkey FOREIGN KEY (parent_identifier_id) REFERENCES mymes.identifier(id) ON DELETE RESTRICT;


--
-- TOC entry 3677 (class 2606 OID 25918)
-- Name: import_schamas_t import_schamas_t_import_schama_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.import_schamas_t
    ADD CONSTRAINT import_schamas_t_import_schama_id_fkey FOREIGN KEY (import_schama_id) REFERENCES mymes.import_schemas(id) ON DELETE CASCADE;


--
-- TOC entry 3676 (class 2606 OID 25842)
-- Name: kit kit_serial_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.kit
    ADD CONSTRAINT kit_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE RESTRICT;


--
-- TOC entry 3685 (class 2606 OID 25923)
-- Name: local_actions_t local_actions_t_local_action_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.local_actions_t
    ADD CONSTRAINT local_actions_t_local_action_id_fkey FOREIGN KEY (local_action_id) REFERENCES mymes.local_actions(id) ON DELETE CASCADE;


--
-- TOC entry 3673 (class 2606 OID 26170)
-- Name: locations locations_act_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.locations
    ADD CONSTRAINT locations_act_id_fkey FOREIGN KEY (act_id) REFERENCES mymes.actions(id) ON DELETE RESTRICT;


--
-- TOC entry 3674 (class 2606 OID 25997)
-- Name: locations locations_part_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.locations
    ADD CONSTRAINT locations_part_id_fkey FOREIGN KEY (part_id) REFERENCES mymes.part(id) ON DELETE RESTRICT;


--
-- TOC entry 3695 (class 2606 OID 26597)
-- Name: fault_status_t malf_status_t_malf_status_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_status_t
    ADD CONSTRAINT malf_status_t_malf_status_id_fkey FOREIGN KEY (fault_status_id) REFERENCES mymes.fault_status(id) ON DELETE CASCADE;


--
-- TOC entry 3696 (class 2606 OID 26842)
-- Name: fault_t malf_t_malf_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_t
    ADD CONSTRAINT malf_t_malf_id_fkey FOREIGN KEY (fault_id) REFERENCES mymes.fault(id) ON DELETE CASCADE;


--
-- TOC entry 3694 (class 2606 OID 26602)
-- Name: fault_type_t malf_type_t_malf_type_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.fault_type_t
    ADD CONSTRAINT malf_type_t_malf_type_id_fkey FOREIGN KEY (fault_type_id) REFERENCES mymes.fault_type(id) ON DELETE CASCADE;


--
-- TOC entry 3662 (class 2606 OID 25933)
-- Name: malfunction_types_t malfunction_types_t_malfunction_type_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.malfunction_types_t
    ADD CONSTRAINT malfunction_types_t_malfunction_type_id_fkey FOREIGN KEY (malfunction_type_id) REFERENCES mymes.malfunction_types(id) ON DELETE CASCADE;


--
-- TOC entry 3660 (class 2606 OID 26027)
-- Name: malfunctions malfunctions_equipment_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.malfunctions
    ADD CONSTRAINT malfunctions_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES mymes.equipments(id) ON DELETE RESTRICT;


--
-- TOC entry 3659 (class 2606 OID 26022)
-- Name: malfunctions malfunctions_malfunction_type_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.malfunctions
    ADD CONSTRAINT malfunctions_malfunction_type_id_fkey FOREIGN KEY (malfunction_type_id) REFERENCES mymes.malfunction_types(id) ON DELETE RESTRICT;


--
-- TOC entry 3661 (class 2606 OID 25938)
-- Name: malfunctions_t malfunctions_t_malfunction_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.malfunctions_t
    ADD CONSTRAINT malfunctions_t_malfunction_id_fkey FOREIGN KEY (malfunction_id) REFERENCES mymes.malfunctions(id) ON DELETE CASCADE;


--
-- TOC entry 3667 (class 2606 OID 26017)
-- Name: mnt_plan_items mnt_plan_items_mnt_plan_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.mnt_plan_items
    ADD CONSTRAINT mnt_plan_items_mnt_plan_id_fkey FOREIGN KEY (mnt_plan_id) REFERENCES mymes.mnt_plans(id) ON DELETE RESTRICT;


--
-- TOC entry 3668 (class 2606 OID 25943)
-- Name: mnt_plans_t mnt_plans_t_mnt_plan_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.mnt_plans_t
    ADD CONSTRAINT mnt_plans_t_mnt_plan_id_fkey FOREIGN KEY (mnt_plan_id) REFERENCES mymes.mnt_plans(id) ON DELETE CASCADE;


--
-- TOC entry 3647 (class 2606 OID 26180)
-- Name: part part_part_status_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part
    ADD CONSTRAINT part_part_status_id_fkey FOREIGN KEY (part_status_id) REFERENCES mymes.part_status(id) ON DELETE RESTRICT;


--
-- TOC entry 3649 (class 2606 OID 25948)
-- Name: part_status_t part_status_t_part_status_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part_status_t
    ADD CONSTRAINT part_status_t_part_status_id_fkey FOREIGN KEY (part_status_id) REFERENCES mymes.part_status(id) ON DELETE CASCADE;


--
-- TOC entry 3648 (class 2606 OID 25953)
-- Name: part_t part_t_part_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.part_t
    ADD CONSTRAINT part_t_part_id_fkey FOREIGN KEY (part_id) REFERENCES mymes.part(id) ON DELETE CASCADE;


--
-- TOC entry 3682 (class 2606 OID 26012)
-- Name: proc_act proc_act_act_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_act_id_fkey FOREIGN KEY (act_id) REFERENCES mymes.actions(id) ON DELETE RESTRICT;


--
-- TOC entry 3681 (class 2606 OID 26007)
-- Name: proc_act proc_act_process_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_process_id_fkey FOREIGN KEY (process_id) REFERENCES mymes.process(id) ON DELETE RESTRICT;


--
-- TOC entry 3680 (class 2606 OID 25958)
-- Name: process_t process_t_process_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.process_t
    ADD CONSTRAINT process_t_process_id_fkey FOREIGN KEY (process_id) REFERENCES mymes.process(id) ON DELETE CASCADE;


--
-- TOC entry 3666 (class 2606 OID 25963)
-- Name: repair_types_t repair_types_t_repair_type_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.repair_types_t
    ADD CONSTRAINT repair_types_t_repair_type_id_fkey FOREIGN KEY (repair_type_id) REFERENCES mymes.repair_types(id) ON DELETE CASCADE;


--
-- TOC entry 3664 (class 2606 OID 26103)
-- Name: repairs repairs_employee_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.repairs
    ADD CONSTRAINT repairs_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES mymes.employees(id) ON DELETE RESTRICT;


--
-- TOC entry 3663 (class 2606 OID 26098)
-- Name: repairs repairs_malfunction_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.repairs
    ADD CONSTRAINT repairs_malfunction_id_fkey FOREIGN KEY (malfunction_id) REFERENCES mymes.malfunctions(id) ON DELETE RESTRICT;


--
-- TOC entry 3665 (class 2606 OID 26108)
-- Name: repairs repairs_repair_type_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.repairs
    ADD CONSTRAINT repairs_repair_type_id_fkey FOREIGN KEY (repair_type_id) REFERENCES mymes.repair_types(id) ON DELETE RESTRICT;


--
-- TOC entry 3655 (class 2606 OID 26140)
-- Name: resource_groups resource_groups_availability_profile_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_groups
    ADD CONSTRAINT resource_groups_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE RESTRICT;


--
-- TOC entry 3645 (class 2606 OID 25975)
-- Name: resource_groups_t resource_groups_t_resource_group_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resource_groups_t
    ADD CONSTRAINT resource_groups_t_resource_group_id_fkey FOREIGN KEY (resource_group_id) REFERENCES mymes.resource_groups(id) ON DELETE CASCADE;


--
-- TOC entry 3650 (class 2606 OID 26037)
-- Name: resources resources_availability_profile_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.resources
    ADD CONSTRAINT resources_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE RESTRICT;


--
-- TOC entry 3683 (class 2606 OID 25643)
-- Name: serial_act serial_act_serial_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serial_act
    ADD CONSTRAINT serial_act_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE CASCADE;


--
-- TOC entry 3678 (class 2606 OID 25982)
-- Name: serial_statuses_t serial_statuses_t_serial_status_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serial_statuses_t
    ADD CONSTRAINT serial_statuses_t_serial_status_id_fkey FOREIGN KEY (serial_status_id) REFERENCES mymes.serial_statuses(id) ON DELETE CASCADE;


--
-- TOC entry 3670 (class 2606 OID 26436)
-- Name: serials serials_parent_serial_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_parent_serial_fkey FOREIGN KEY (parent_serial) REFERENCES mymes.serials(id) ON DELETE RESTRICT;


--
-- TOC entry 3671 (class 2606 OID 26115)
-- Name: serials serials_part_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_part_id_fkey FOREIGN KEY (part_id) REFERENCES mymes.part(id) ON DELETE RESTRICT;


--
-- TOC entry 3672 (class 2606 OID 26120)
-- Name: serials serials_process_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_process_id_fkey FOREIGN KEY (process_id) REFERENCES mymes.process(id) ON DELETE RESTRICT;


--
-- TOC entry 3669 (class 2606 OID 26195)
-- Name: serials serials_status_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_status_fkey FOREIGN KEY (status) REFERENCES mymes.serial_statuses(id) ON DELETE RESTRICT;


--
-- TOC entry 3679 (class 2606 OID 25827)
-- Name: serials_t serials_t_serial_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.serials_t
    ADD CONSTRAINT serials_t_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE CASCADE;


--
-- TOC entry 3658 (class 2606 OID 25987)
-- Name: standards_types_t standards_types_t_standard_type_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.standards_types_t
    ADD CONSTRAINT standards_types_t_standard_type_id_fkey FOREIGN KEY (standard_type_id) REFERENCES mymes.standards(id) ON DELETE CASCADE;


--
-- TOC entry 3687 (class 2606 OID 26125)
-- Name: work_report work_report_act_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_act_id_fkey FOREIGN KEY (act_id) REFERENCES mymes.actions(id) ON DELETE RESTRICT;


--
-- TOC entry 3686 (class 2606 OID 25808)
-- Name: work_report work_report_serial_id_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE RESTRICT;


--
-- TOC entry 3688 (class 2606 OID 26130)
-- Name: work_report work_report_sig_user_fkey; Type: FK CONSTRAINT; Schema: mymes; Owner: -
--

ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_sig_user_fkey FOREIGN KEY (sig_user) REFERENCES public.users(id) ON DELETE RESTRICT;


-- Completed on 2019-11-07 08:21:47

--
-- PostgreSQL database dump complete
--

