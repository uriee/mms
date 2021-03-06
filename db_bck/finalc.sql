PGDMP     ;    #                 x            mymes %   10.10 (Ubuntu 10.10-0ubuntu0.18.04.1)    11.3 �   �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                       false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                       false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                       false            �           1262    16387    mymes    DATABASE     w   CREATE DATABASE mymes WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';
    DROP DATABASE mymes;
             cbtpost    false                        2615    16388    mymes    SCHEMA        CREATE SCHEMA mymes;
    DROP SCHEMA mymes;
             cbtpost    false                        2615    16917    test    SCHEMA        CREATE SCHEMA test;
    DROP SCHEMA test;
             cbtpost    false            '           1247    26214    approval    TYPE     `   CREATE TYPE public.approval AS ENUM (
    'Pending approval',
    'Approved',
    'Rejected'
);
    DROP TYPE public.approval;
       public       admin    false            �           1247    27504    condition_t    TYPE     �   CREATE TYPE public.condition_t AS ENUM (
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
    DROP TYPE public.condition_t;
       public       admin    false            $           1247    26207    delivery_method    TYPE     g   CREATE TYPE public.delivery_method AS ENUM (
    'Integral email',
    'External email',
    'Both'
);
 "   DROP TYPE public.delivery_method;
       public       admin    false            u           1247    17071    equipment_type    TYPE     b   CREATE TYPE public.equipment_type AS ENUM (
    'Machine',
    'Tool',
    'Machine accessory'
);
 !   DROP TYPE public.equipment_type;
       public       cbtpost    false            6           1247    17088    malfunction_status    TYPE     c   CREATE TYPE public.malfunction_status AS ENUM (
    'Open',
    'Under Treatment',
    'Closed'
);
 %   DROP TYPE public.malfunction_status;
       public       cbtpost    false            .           1247    26260    manager_type    TYPE     Z   CREATE TYPE public.manager_type AS ENUM (
    'None',
    'Manager',
    'Manager(HR)'
);
    DROP TYPE public.manager_type;
       public       admin    false            !           1247    25592    notifications_type    TYPE     b   CREATE TYPE public.notifications_type AS ENUM (
    'notification',
    'message',
    'event'
);
 %   DROP TYPE public.notifications_type;
       public       admin    false            �           1247    16988    row_type    TYPE     �  CREATE TYPE public.row_type AS ENUM (
    'employees',
    'machine',
    'equipments',
    'place',
    'resource_groups',
    'part',
    'mnt_plans',
    'malfunctions',
    'repairs',
    'availability_profile',
    'dept',
    'actions',
    'serials',
    'serial_status',
    'process',
    'part_status',
    'user',
    'fault',
    'fault_type',
    'fault_status',
    'positions',
    'malf',
    'malf_type',
    'malf_status',
    'work_report',
    'identifier_links',
    'fix'
);
    DROP TYPE public.row_type;
       public       cbtpost    false            �           1255    27007 /   check_identifier_exists(text, text, text, text)    FUNCTION     9  CREATE FUNCTION public.check_identifier_exists(serial_name text, act_name text, row_type text, iden text) RETURNS integer
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
 i   DROP FUNCTION public.check_identifier_exists(serial_name text, act_name text, row_type text, iden text);
       public       admin    false            �           1255    27005    check_serial_act()    FUNCTION     x  CREATE FUNCTION public.check_serial_act() RETURNS trigger
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
 )   DROP FUNCTION public.check_serial_act();
       public       admin    false            ~           1255    26975 %   check_serial_act(text, text, integer)    FUNCTION     @  CREATE FUNCTION public.check_serial_act(serial_name text, act_name text, pbal integer) RETURNS integer
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
 V   DROP FUNCTION public.check_serial_act(serial_name text, act_name text, pbal integer);
       public       admin    false            w           1255    25469 -   check_serial_act_balance(text, text, integer)    FUNCTION     u  CREATE FUNCTION public.check_serial_act_balance(serial_name text, act_name text, pbal integer) RETURNS integer
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
 ^   DROP FUNCTION public.check_serial_act_balance(serial_name text, act_name text, pbal integer);
       public       admin    false            {           1255    26514    clone_actions(integer)    FUNCTION       CREATE FUNCTION public.clone_actions(idp integer) RETURNS integer
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
 1   DROP FUNCTION public.clone_actions(idp integer);
       public       admin    false            t           1255    26501    clone_equipments(integer)    FUNCTION     9  CREATE FUNCTION public.clone_equipments(e_param integer) RETURNS integer
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
 8   DROP FUNCTION public.clone_equipments(e_param integer);
       public       admin    false            }           1255    25443    clone_parts(integer)    FUNCTION     �  CREATE FUNCTION public.clone_parts(part_param integer) RETURNS integer
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
 6   DROP FUNCTION public.clone_parts(part_param integer);
       public       admin    false                       1255    26513    clone_process(integer)    FUNCTION     L  CREATE FUNCTION public.clone_process(idp integer) RETURNS integer
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
 1   DROP FUNCTION public.clone_process(idp integer);
       public       admin    false            p           1255    26494    clone_resource_groups(integer)    FUNCTION     �  CREATE FUNCTION public.clone_resource_groups(rg_param integer) RETURNS integer
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
 >   DROP FUNCTION public.clone_resource_groups(rg_param integer);
       public       admin    false            �           1255    25365     cpy_acts_proc2ser(integer, text)    FUNCTION     �  CREATE FUNCTION public.cpy_acts_proc2ser(ser integer, proc text) RETURNS integer
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
 @   DROP FUNCTION public.cpy_acts_proc2ser(ser integer, proc text);
       public       admin    false            j           1255    25560    cpy_resource_timeoffs(integer)    FUNCTION     w  CREATE FUNCTION public.cpy_resource_timeoffs(timeoff_id integer) RETURNS integer
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
 @   DROP FUNCTION public.cpy_resource_timeoffs(timeoff_id integer);
       public       admin    false            c           1255    26403 %   cpy_resources_act2proc(integer, text)    FUNCTION     �  CREATE FUNCTION public.cpy_resources_act2proc(proc_id integer, act text) RETURNS integer
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
 H   DROP FUNCTION public.cpy_resources_act2proc(proc_id integer, act text);
       public       admin    false            s           1255    26925 )   delete_identifier_link(integer[], text[])    FUNCTION     d  CREATE FUNCTION public.delete_identifier_link(pids integer[], params text[]) RETURNS integer
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
 L   DROP FUNCTION public.delete_identifier_link(pids integer[], params text[]);
       public       admin    false            d           1255    25564 #   delete_resource_timeoffs(integer[])    FUNCTION     m  CREATE FUNCTION public.delete_resource_timeoffs(timeoff_id integer[]) RETURNS integer
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
 E   DROP FUNCTION public.delete_resource_timeoffs(timeoff_id integer[]);
       public       admin    false            �           1255    35711    event_trigger_delete()    FUNCTION     h  CREATE FUNCTION public.event_trigger_delete() RETURNS trigger
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
			IF(ret > 0) THEN
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
 -   DROP FUNCTION public.event_trigger_delete();
       public       admin    false            �           1255    35710    event_trigger_insert()    FUNCTION     	  CREATE FUNCTION public.event_trigger_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
	ret integer;
	trig record;
	queue text;
	link_name text;
	link_schema text;
BEGIN
	FOR trig IN SELECT * FROM mymes.event_triggers WHERE table_id = TG_TABLE_NAME and active is true 
    	LOOP
			EXECUTE trig.insert_sql into ret USING NEW;
			RAISE log '1111 % - EROOR:%' , ret,trig.error;
			IF(ret = 1) THEN
				
				IF(array_length(trig.queues, 1) > 0 ) then
					
					if (NEW.name is not null) then link_name = NEW.name; end if;
					if (NEW.row_type is not null) then link_schema = NEW.row_type; end if;
					FOREACH queue IN ARRAY trig.queues
					   LOOP
					   	RAISE log '444 %' , queue;
						  insert into mymes.notifications(title,username,type,extra,schema) values(trig.message_text,queue,'notification',link_name,link_schema);
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
 -   DROP FUNCTION public.event_trigger_insert();
       public       admin    false            �           1255    35811 '   event_trigger_insert_identifier_links()    FUNCTION     �  CREATE FUNCTION public.event_trigger_insert_identifier_links() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$

declare
	ret integer;
	trig record;
	queue text;
	test integer;
	dsql text;
BEGIN
	FOR trig IN SELECT * FROM mymes.event_triggers WHERE table_id = TG_TABLE_NAME and active is true 
    	LOOP
			EXECUTE trig.insert_sql into ret USING NEW;
			IF(ret = 1) THEN
				IF(array_length(trig.queues, 1) > 0 ) then
					FOREACH queue IN ARRAY trig.queues
					   LOOP
						  insert into mymes.notifications(title,username,type,extra,schema) values(trig.message_text,queue,'notification',NEW.name,NEW.row_type);
					   END LOOP;
				END IF;
				IF(trig.error is true) THEN
					dsql = 'delete from mymes.' || NEW.row_type || ' where id = $1.parent_id RETURNING id ;' ;
					EXECUTE dsql into test USING NEW;

					RAISE EXCEPTION '%' , trig.message_text; 
					RETURN NULL; 
				END IF;
			END IF;
   		END LOOP;

 RETURN NEW ;

END ; 

$_$;
 >   DROP FUNCTION public.event_trigger_insert_identifier_links();
       public       admin    false            �           1255    35695    event_trigger_update()    FUNCTION     �  CREATE FUNCTION public.event_trigger_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

declare
	ret integer;
	trig record;
	queue text;
	link_name text;
	link_schema text;

BEGIN

	FOR trig IN SELECT * FROM mymes.event_triggers WHERE table_id = TG_TABLE_NAME and active is true 
    	LOOP
			EXECUTE trig.update_sql into ret USING NEW,OLD;
			RAISE log '1111 % - EROOR:%' , ret,trig.error;
			IF(ret > 0) THEN
				RAISE log '2222 % , %' , trig.queues,array_length(trig.queues, 1);
				IF(trig.error is not true and array_length(trig.queues, 1) > 0 ) then
					if (NEW.name is not null) then link_name = NEW.name; end if;
					if (NEW.row_type is not null) then link_schema = NEW.row_type; end if;				
					FOREACH queue IN ARRAY trig.queues
					   LOOP
					   	RAISE log '444 %' , queue;
						  insert into mymes.notifications(title,username,type,extra,schema) values(trig.message_text,queue,'notification',link_name,link_schema);
						RAISE log '555 %' , queue;  
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
 -   DROP FUNCTION public.event_trigger_update();
       public       admin    false            |           1255    26973    fault_notify()    FUNCTION     �  CREATE FUNCTION public.fault_notify() RETURNS trigger
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
 %   DROP FUNCTION public.fault_notify();
       public       admin    false            �           1255    26997 0   insert_identifier_link_post(integer, text, text)    FUNCTION     &  CREATE FUNCTION public.insert_identifier_link_post(parent integer, row_type text, iden text) RETURNS integer
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
 \   DROP FUNCTION public.insert_identifier_link_post(parent integer, row_type text, iden text);
       public       admin    false            z           1255    27444 ;   insert_identifier_link_post(integer, text, text, integer[])    FUNCTION     �  CREATE FUNCTION public.insert_identifier_link_post(parent integer, row_type text, iden text, batch_array integer[]) RETURNS integer
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
 s   DROP FUNCTION public.insert_identifier_link_post(parent integer, row_type text, iden text, batch_array integer[]);
       public       admin    false            o           1255    26996 /   insert_identifier_link_pre(integer, text, text)    FUNCTION     �  CREATE FUNCTION public.insert_identifier_link_pre(parent integer, row_type text, iden text) RETURNS integer
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
 [   DROP FUNCTION public.insert_identifier_link_pre(parent integer, row_type text, iden text);
       public       admin    false            k           1255    26484    mes_notify()    FUNCTION     �  CREATE FUNCTION public.mes_notify() RETURNS trigger
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
 #   DROP FUNCTION public.mes_notify();
       public       admin    false            r           1255    27402    post_delete_identifier()    FUNCTION     �   CREATE FUNCTION public.post_delete_identifier() RETURNS trigger
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
 /   DROP FUNCTION public.post_delete_identifier();
       public       admin    false            �           1255    27432    post_insert_identifier_link()    FUNCTION     .  CREATE FUNCTION public.post_insert_identifier_link() RETURNS trigger
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
 4   DROP FUNCTION public.post_insert_identifier_link();
       public       admin    false            �           1255    27481    pre_delete_approved()    FUNCTION     [  CREATE FUNCTION public.pre_delete_approved() RETURNS trigger
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
 ,   DROP FUNCTION public.pre_delete_approved();
       public       admin    false            l           1255    26910    pre_delete_identifier()    FUNCTION     T  CREATE FUNCTION public.pre_delete_identifier() RETURNS trigger
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
 .   DROP FUNCTION public.pre_delete_identifier();
       public       admin    false            h           1255    26902    pre_delete_sendable()    FUNCTION     X  CREATE FUNCTION public.pre_delete_sendable() RETURNS trigger
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
 ,   DROP FUNCTION public.pre_delete_sendable();
       public       admin    false            x           1255    26963    pre_insert_identifier()    FUNCTION     9  CREATE FUNCTION public.pre_insert_identifier() RETURNS trigger
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
 .   DROP FUNCTION public.pre_insert_identifier();
       public       admin    false            e           1255    26427    resources_by_parent(integer)    FUNCTION     �  CREATE FUNCTION public.resources_by_parent(res integer) RETURNS TABLE(resource integer, depth integer)
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
 7   DROP FUNCTION public.resources_by_parent(res integer);
       public       admin    false            V           1255    17023    set_availabilities(integer)    FUNCTION     �  CREATE FUNCTION public.set_availabilities(apid integer) RETURNS integer
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
 7   DROP FUNCTION public.set_availabilities(apid integer);
       public       admin    false            n           1255    27308    set_fault_status()    FUNCTION     $  CREATE FUNCTION public.set_fault_status() RETURNS trigger
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
 )   DROP FUNCTION public.set_fault_status();
       public       admin    false            u           1255    26940 
   set_name()    FUNCTION        CREATE FUNCTION public.set_name() RETURNS trigger
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
 !   DROP FUNCTION public.set_name();
       public       admin    false            �           1255    35688    trig_cond_to_string(json, text)    FUNCTION     �  CREATE FUNCTION public.trig_cond_to_string(trig_cond json, old_logic_gate text) RETURNS text
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
 O   DROP FUNCTION public.trig_cond_to_string(trig_cond json, old_logic_gate text);
       public       admin    false            �           1255    27478    trigger_set_sig_date()    FUNCTION     �   CREATE FUNCTION public.trigger_set_sig_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.sig_date = NOW();
  RETURN NEW;
END;
$$;
 -   DROP FUNCTION public.trigger_set_sig_date();
       public       admin    false            v           1255    26976    trigger_set_timestamp()    FUNCTION     �   CREATE FUNCTION public.trigger_set_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;
 .   DROP FUNCTION public.trigger_set_timestamp();
       public       admin    false            m           1255    25473 "   update_serial_act_balance(integer)    FUNCTION     �  CREATE FUNCTION public.update_serial_act_balance(pid integer) RETURNS integer
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
 =   DROP FUNCTION public.update_serial_act_balance(pid integer);
       public       admin    false            �           1255    27276 ,   update_serial_act_balance(integer[], text[])    FUNCTION     T  CREATE FUNCTION public.update_serial_act_balance(pids integer[], params text[]) RETURNS integer
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
 O   DROP FUNCTION public.update_serial_act_balance(pids integer[], params text[]);
       public       admin    false            i           1255    25470 .   update_serial_act_balance(text, text, integer)    FUNCTION     �  CREATE FUNCTION public.update_serial_act_balance(serial_name text, act_name text, qnt integer) RETURNS integer
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
 ^   DROP FUNCTION public.update_serial_act_balance(serial_name text, act_name text, qnt integer);
       public       admin    false            g           1255    26430 (   user_parent_resources(character varying)    FUNCTION     c  CREATE FUNCTION public.user_parent_resources(usr character varying) RETURNS TABLE(resource integer, depth integer)
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
 C   DROP FUNCTION public.user_parent_resources(usr character varying);
       public       admin    false            y           1255    26968 $   user_parent_users(character varying)    FUNCTION     �  CREATE FUNCTION public.user_parent_users(usr character varying) RETURNS TABLE(username character varying)
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
 ?   DROP FUNCTION public.user_parent_users(usr character varying);
       public       admin    false            f           1255    26429 +   user_resources_by_parent(character varying)    FUNCTION     �  CREATE FUNCTION public.user_resources_by_parent(usrname character varying) RETURNS TABLE(resource integer, depth integer)
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
 J   DROP FUNCTION public.user_resources_by_parent(usrname character varying);
       public       admin    false            q           1255    26492    work_report_notify()    FUNCTION     �  CREATE FUNCTION public.work_report_notify() RETURNS trigger
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
 +   DROP FUNCTION public.work_report_notify();
       public       admin    false            �            1259    16965     utilization    TABLE     v   CREATE TABLE mymes." utilization" (
    id integer NOT NULL,
    resource_id integer NOT NULL,
    udate daterange
);
 !   DROP TABLE mymes." utilization";
       mymes         cbtpost    false    5            �            1259    16963     utilization_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes." utilization_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE mymes." utilization_id_seq";
       mymes       cbtpost    false    226    5            �           0    0     utilization_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE mymes." utilization_id_seq" OWNED BY mymes." utilization".id;
            mymes       cbtpost    false    225            �            1259    16557    permissions    TABLE     �   CREATE TABLE mymes.permissions (
    entity integer NOT NULL,
    field integer,
    read boolean,
    write boolean,
    delete boolean,
    profile_id integer,
    id integer NOT NULL,
    ws smallint
);
    DROP TABLE mymes.permissions;
       mymes         cbtpost    false    5            �            1259    16697    PERMISSIONS_PERMISION_seq    SEQUENCE     �   CREATE SEQUENCE mymes."PERMISSIONS_PERMISION_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE mymes."PERMISSIONS_PERMISION_seq";
       mymes       cbtpost    false    204    5            �           0    0    PERMISSIONS_PERMISION_seq    SEQUENCE OWNED BY     P   ALTER SEQUENCE mymes."PERMISSIONS_PERMISION_seq" OWNED BY mymes.permissions.id;
            mymes       cbtpost    false    206            0           1259    26388    act_resources    TABLE     �   CREATE TABLE mymes.act_resources (
    resource_id integer NOT NULL,
    act_id integer NOT NULL,
    id integer NOT NULL,
    ord smallint NOT NULL,
    type smallint NOT NULL
);
     DROP TABLE mymes.act_resources;
       mymes         admin    false    5            /           1259    26386    act_resources_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.act_resources_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE mymes.act_resources_id_seq;
       mymes       admin    false    304    5            �           0    0    act_resources_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE mymes.act_resources_id_seq OWNED BY mymes.act_resources.id;
            mymes       admin    false    303            �            1259    17215    tagable    TABLE        CREATE TABLE mymes.tagable (
    tags text[],
    row_type public.row_type,
    name text NOT NULL,
    id integer NOT NULL
);
    DROP TABLE mymes.tagable;
       mymes         cbtpost    false    956    5                       1259    25207    actions    TABLE     �   CREATE TABLE mymes.actions (
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
    DROP TABLE mymes.actions;
       mymes         admin    false    5    252    956                       1259    25205    actions_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE mymes.actions_id_seq;
       mymes       admin    false    261    5            �           0    0    actions_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE mymes.actions_id_seq OWNED BY mymes.actions.id;
            mymes       admin    false    260                       1259    25216 	   actions_t    TABLE     ~   CREATE TABLE mymes.actions_t (
    action_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
    DROP TABLE mymes.actions_t;
       mymes         admin    false    5            $           1259    25528    resource_timeoff    TABLE     Y  CREATE TABLE mymes.resource_timeoff (
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
 #   DROP TABLE mymes.resource_timeoff;
       mymes         admin    false    1063    5            #           1259    25526    ap_holidays_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.ap_holidays_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE mymes.ap_holidays_id_seq;
       mymes       admin    false    292    5            �           0    0    ap_holidays_id_seq    SEQUENCE OWNED BY     L   ALTER SEQUENCE mymes.ap_holidays_id_seq OWNED BY mymes.resource_timeoff.id;
            mymes       admin    false    291            �            1259    16960    availabilities    TABLE     �   CREATE TABLE mymes.availabilities (
    availability_profile_id integer NOT NULL,
    weekday smallint NOT NULL,
    from_time time(6) without time zone,
    to_time time(6) without time zone,
    id integer NOT NULL,
    flag_o boolean
);
 !   DROP TABLE mymes.availabilities;
       mymes         cbtpost    false    5            �            1259    17015    availabilities_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.availabilities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE mymes.availabilities_id_seq;
       mymes       cbtpost    false    224    5            �           0    0    availabilities_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE mymes.availabilities_id_seq OWNED BY mymes.availabilities.id;
            mymes       cbtpost    false    228            �            1259    16954    availability_profiles    TABLE     �   CREATE TABLE mymes.availability_profiles (
    id integer,
    name text,
    active boolean,
    tags text[],
    row_type public.row_type
)
INHERITS (mymes.tagable);
 (   DROP TABLE mymes.availability_profiles;
       mymes         cbtpost    false    956    252    5            �            1259    16952    availability_profile_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.availability_profile_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE mymes.availability_profile_id_seq;
       mymes       cbtpost    false    223    5            �           0    0    availability_profile_id_seq    SEQUENCE OWNED BY     Z   ALTER SEQUENCE mymes.availability_profile_id_seq OWNED BY mymes.availability_profiles.id;
            mymes       cbtpost    false    222            �            1259    16997    availability_profiles_t    TABLE        CREATE TABLE mymes.availability_profiles_t (
    ap_id integer NOT NULL,
    description text,
    lang_id integer NOT NULL
);
 *   DROP TABLE mymes.availability_profiles_t;
       mymes         cbtpost    false    5                       1259    25368    bom    TABLE     �   CREATE TABLE mymes.bom (
    id integer NOT NULL,
    parent_id integer NOT NULL,
    partname text NOT NULL,
    coef real NOT NULL,
    produce boolean
);
    DROP TABLE mymes.bom;
       mymes         admin    false    5                       1259    25366 
   bom_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.bom_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
     DROP SEQUENCE mymes.bom_id_seq;
       mymes       admin    false    280    5            �           0    0 
   bom_id_seq    SEQUENCE OWNED BY     7   ALTER SEQUENCE mymes.bom_id_seq OWNED BY mymes.bom.id;
            mymes       admin    false    279            Q           1259    27488    event_triggers    TABLE     .  CREATE TABLE mymes.event_triggers (
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
    del boolean,
    link text
);
 !   DROP TABLE mymes.event_triggers;
       mymes         admin    false    5            P           1259    27486    checks_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.checks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE mymes.checks_id_seq;
       mymes       admin    false    337    5            �           0    0    checks_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE mymes.checks_id_seq OWNED BY mymes.event_triggers.id;
            mymes       admin    false    336            �            1259    16858    configurations    TABLE     b   CREATE TABLE mymes.configurations (
    key character varying NOT NULL,
    intarray integer[]
);
 !   DROP TABLE mymes.configurations;
       mymes         cbtpost    false    5            3           1259    26502    convers    TABLE     �   CREATE TABLE mymes.convers (
    id integer,
    row_type public.row_type,
    messsage text,
    author text,
    "user" integer,
    udate timestamp without time zone
);
    DROP TABLE mymes.convers;
       mymes         admin    false    5    956            �            1259    16836    departments    TABLE     �   CREATE TABLE mymes.departments (
    name text,
    id integer,
    tags text[],
    row_type public.row_type
)
INHERITS (mymes.tagable);
    DROP TABLE mymes.departments;
       mymes         cbtpost    false    956    252    5            �            1259    16834    departments_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.departments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE mymes.departments_id_seq;
       mymes       cbtpost    false    5    209            �           0    0    departments_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE mymes.departments_id_seq OWNED BY mymes.departments.id;
            mymes       cbtpost    false    208            �            1259    16831    departments_t    TABLE     �   CREATE TABLE mymes.departments_t (
    description character varying(80) NOT NULL,
    dept_id integer NOT NULL,
    lang_id integer NOT NULL
);
     DROP TABLE mymes.departments_t;
       mymes         cbtpost    false    5            �            1259    16920 	   resources    TABLE     2  CREATE TABLE mymes.resources (
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
    DROP TABLE mymes.resources;
       mymes         cbtpost    false    956    252    5            �            1259    16926 	   employees    TABLE     H  CREATE TABLE mymes.employees (
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
    DROP TABLE mymes.employees;
       mymes         cbtpost    false    218    5    956    1060            �            1259    16540    employees_t    TABLE     �   CREATE TABLE mymes.employees_t (
    emp_id integer,
    lang_id integer,
    fname text NOT NULL,
    sname text,
    ws smallint
);
    DROP TABLE mymes.employees_t;
       mymes         cbtpost    false    5            �            1259    16930 
   equipments    TABLE       CREATE TABLE mymes.equipments (
    name text,
    mac_address macaddr,
    serial text,
    equipment_type public.equipment_type,
    calibrated boolean,
    resource_ids integer[],
    last_calibration timestamp without time zone
)
INHERITS (mymes.resources);
    DROP TABLE mymes.equipments;
       mymes         cbtpost    false    218    885    956    5            �            1259    16543    equipments_t    TABLE     z   CREATE TABLE mymes.equipments_t (
    equipment_id integer,
    lang_id integer,
    description text,
    ws smallint
);
    DROP TABLE mymes.equipments_t;
       mymes         cbtpost    false    5            =           1259    26688    sendable    TABLE       CREATE TABLE mymes.sendable (
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
    DROP TABLE mymes.sendable;
       mymes         admin    false    956    5            9           1259    26557    fault    TABLE     �  CREATE TABLE mymes.fault (
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
    DROP TABLE mymes.fault;
       mymes         admin    false    956    252    5    317            7           1259    26542    fault_status    TABLE     �   CREATE TABLE mymes.fault_status (
    id integer,
    name text,
    tags text[],
    row_type public.row_type,
    active boolean,
    first boolean,
    sendable boolean
)
INHERITS (mymes.tagable);
    DROP TABLE mymes.fault_status;
       mymes         admin    false    252    5    956            ;           1259    26575    fault_status_t    TABLE     �   CREATE TABLE mymes.fault_status_t (
    fault_status_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
 !   DROP TABLE mymes.fault_status_t;
       mymes         admin    false    5            <           1259    26581    fault_t    TABLE     {   CREATE TABLE mymes.fault_t (
    fault_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
    DROP TABLE mymes.fault_t;
       mymes         admin    false    5            5           1259    26518 
   fault_type    TABLE     �   CREATE TABLE mymes.fault_type (
    name text,
    id integer,
    tags text[],
    row_type public.row_type,
    active boolean,
    extname text
)
INHERITS (mymes.tagable);
    DROP TABLE mymes.fault_type;
       mymes         admin    false    5    956    252            C           1259    27277    fault_type_act    TABLE     �   CREATE TABLE mymes.fault_type_act (
    fault_type_id integer NOT NULL,
    action_id integer NOT NULL,
    id integer NOT NULL
);
 !   DROP TABLE mymes.fault_type_act;
       mymes         admin    false    5            D           1259    27287    fault_type_act_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.fault_type_act_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE mymes.fault_type_act_id_seq;
       mymes       admin    false    323    5            �           0    0    fault_type_act_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE mymes.fault_type_act_id_seq OWNED BY mymes.fault_type_act.id;
            mymes       admin    false    324            :           1259    26569    fault_type_t    TABLE     �   CREATE TABLE mymes.fault_type_t (
    fault_type_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
    DROP TABLE mymes.fault_type_t;
       mymes         admin    false    5            F           1259    27341    fix    TABLE     �   CREATE TABLE mymes.fix (
    name text NOT NULL,
    id integer NOT NULL,
    tags text[],
    row_type public.row_type,
    active boolean,
    extname text
);
    DROP TABLE mymes.fix;
       mymes         admin    false    956    5            J           1259    27383    fix_act    TABLE     u   CREATE TABLE mymes.fix_act (
    fix_id integer NOT NULL,
    action_id integer NOT NULL,
    id integer NOT NULL
);
    DROP TABLE mymes.fix_act;
       mymes         admin    false    5            I           1259    27381    fix_act_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.fix_act_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE mymes.fix_act_id_seq;
       mymes       admin    false    5    330            �           0    0    fix_act_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE mymes.fix_act_id_seq OWNED BY mymes.fix_act.id;
            mymes       admin    false    329            E           1259    27339 
   fix_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.fix_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
     DROP SEQUENCE mymes.fix_id_seq;
       mymes       admin    false    326    5            �           0    0 
   fix_id_seq    SEQUENCE OWNED BY     7   ALTER SEQUENCE mymes.fix_id_seq OWNED BY mymes.fix.id;
            mymes       admin    false    325            H           1259    27356    fix_t    TABLE     w   CREATE TABLE mymes.fix_t (
    fix_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
    DROP TABLE mymes.fix_t;
       mymes         admin    false    5            G           1259    27354    fix_t_fix_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.fix_t_fix_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE mymes.fix_t_fix_id_seq;
       mymes       admin    false    328    5            �           0    0    fix_t_fix_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE mymes.fix_t_fix_id_seq OWNED BY mymes.fix_t.fix_id;
            mymes       admin    false    327                        1259    25478 
   identifier    TABLE       CREATE TABLE mymes.identifier (
    id integer NOT NULL,
    name text NOT NULL,
    parent_id integer,
    created_at timestamp(6) with time zone DEFAULT now(),
    parent_identifier_id integer,
    mac_address macaddr,
    secondary text,
    batch text
);
    DROP TABLE mymes.identifier;
       mymes         admin    false    5            >           1259    26693    identifier_links    TABLE     +  CREATE TABLE mymes.identifier_links (
    identifier_id bigint NOT NULL,
    parent_id integer NOT NULL,
    row_type public.row_type NOT NULL,
    serial_id integer,
    act_id integer,
    created_at timestamp(6) with time zone DEFAULT now(),
    batch_array integer[],
    id integer NOT NULL
);
 #   DROP TABLE mymes.identifier_links;
       mymes         admin    false    5    956            U           1259    35798    identifier_links_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.identifier_links_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE mymes.identifier_links_id_seq;
       mymes       admin    false    5    318            �           0    0    identifier_links_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE mymes.identifier_links_id_seq OWNED BY mymes.identifier_links.id;
            mymes       admin    false    341                       1259    25476    identifiers_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.identifiers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE mymes.identifiers_id_seq;
       mymes       admin    false    288    5            �           0    0    identifiers_id_seq    SEQUENCE OWNED BY     F   ALTER SEQUENCE mymes.identifiers_id_seq OWNED BY mymes.identifier.id;
            mymes       admin    false    287            
           1259    25246    import_schamas_t    TABLE     �   CREATE TABLE mymes.import_schamas_t (
    import_schama_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
 #   DROP TABLE mymes.import_schamas_t;
       mymes         admin    false    5            	           1259    25237    import_schemas    TABLE     q   CREATE TABLE mymes.import_schemas (
    id integer NOT NULL,
    name text NOT NULL,
    schema text NOT NULL
);
 !   DROP TABLE mymes.import_schemas;
       mymes         admin    false    5                       1259    25235    import_schemas_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.import_schemas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE mymes.import_schemas_id_seq;
       mymes       admin    false    5    265            �           0    0    import_schemas_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE mymes.import_schemas_id_seq OWNED BY mymes.import_schemas.id;
            mymes       admin    false    264                       1259    25227    kit    TABLE     �   CREATE TABLE mymes.kit (
    serial_id integer NOT NULL,
    partname text NOT NULL,
    quant real NOT NULL,
    lot text,
    balance real,
    id bigint NOT NULL,
    in_use boolean
);
    DROP TABLE mymes.kit;
       mymes         admin    false    5                       1259    25377 
   kit_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.kit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
     DROP SEQUENCE mymes.kit_id_seq;
       mymes       admin    false    5    263            �           0    0 
   kit_id_seq    SEQUENCE OWNED BY     7   ALTER SEQUENCE mymes.kit_id_seq OWNED BY mymes.kit.id;
            mymes       admin    false    281            M           1259    27449 	   kit_usage    TABLE     �   CREATE TABLE mymes.kit_usage (
    kit_id integer NOT NULL,
    start_date timestamp without time zone NOT NULL,
    stop_date timestamp without time zone NOT NULL,
    usage integer NOT NULL
);
    DROP TABLE mymes.kit_usage;
       mymes         admin    false    5            �            1259    16470 	   languages    TABLE     c   CREATE TABLE mymes.languages (
    name character varying(20) NOT NULL,
    id integer NOT NULL
);
    DROP TABLE mymes.languages;
       mymes         cbtpost    false    5                       1259    25410    local_actions    TABLE     {   CREATE TABLE mymes.local_actions (
    id integer NOT NULL,
    name text NOT NULL,
    command text,
    type_sig text
);
     DROP TABLE mymes.local_actions;
       mymes         admin    false    5                       1259    25408    local_actions_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.local_actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE mymes.local_actions_id_seq;
       mymes       admin    false    283    5            �           0    0    local_actions_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE mymes.local_actions_id_seq OWNED BY mymes.local_actions.id;
            mymes       admin    false    282                       1259    25431    local_actions_t    TABLE     �   CREATE TABLE mymes.local_actions_t (
    local_action_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);
 "   DROP TABLE mymes.local_actions_t;
       mymes         admin    false    5                       1259    25192 	   locations    TABLE     �   CREATE TABLE mymes.locations (
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
    DROP TABLE mymes.locations;
       mymes         admin    false    5                       1259    25290    locations_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.locations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE mymes.locations_id_seq;
       mymes       admin    false    259    5            �           0    0    locations_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE mymes.locations_id_seq OWNED BY mymes.locations.id;
            mymes       admin    false    271            N           1259    27454    lot_swap    TABLE       CREATE TABLE mymes.lot_swap (
    resource_id integer NOT NULL,
    serial_id integer NOT NULL,
    act_id integer NOT NULL,
    user_id integer NOT NULL,
    lot_old text,
    lot_new text NOT NULL,
    updated_at timestamp without time zone,
    id bigint NOT NULL
);
    DROP TABLE mymes.lot_swap;
       mymes         admin    false    5            O           1259    27466    lot_swap_id_seq    SEQUENCE     w   CREATE SEQUENCE mymes.lot_swap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE mymes.lot_swap_id_seq;
       mymes       admin    false    5    334            �           0    0    lot_swap_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE mymes.lot_swap_id_seq OWNED BY mymes.lot_swap.id;
            mymes       admin    false    335            8           1259    26555    malf_id_seq    SEQUENCE     s   CREATE SEQUENCE mymes.malf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 !   DROP SEQUENCE mymes.malf_id_seq;
       mymes       admin    false    5    313            �           0    0    malf_id_seq    SEQUENCE OWNED BY     :   ALTER SEQUENCE mymes.malf_id_seq OWNED BY mymes.fault.id;
            mymes       admin    false    312            6           1259    26540    malf_status_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.malf_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE mymes.malf_status_id_seq;
       mymes       admin    false    5    311            �           0    0    malf_status_id_seq    SEQUENCE OWNED BY     H   ALTER SEQUENCE mymes.malf_status_id_seq OWNED BY mymes.fault_status.id;
            mymes       admin    false    310            4           1259    26516    malf_type_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.malf_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE mymes.malf_type_id_seq;
       mymes       admin    false    5    309            �           0    0    malf_type_id_seq    SEQUENCE OWNED BY     D   ALTER SEQUENCE mymes.malf_type_id_seq OWNED BY mymes.fault_type.id;
            mymes       admin    false    308            �            1259    17107    malfunction_types    TABLE     Z   CREATE TABLE mymes.malfunction_types (
    id integer NOT NULL,
    name text NOT NULL
);
 $   DROP TABLE mymes.malfunction_types;
       mymes         cbtpost    false    5            �            1259    17105    malfunction_types_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.malfunction_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE mymes.malfunction_types_id_seq;
       mymes       cbtpost    false    237    5            �           0    0    malfunction_types_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE mymes.malfunction_types_id_seq OWNED BY mymes.malfunction_types.id;
            mymes       cbtpost    false    236            �            1259    17142    malfunction_types_t    TABLE     �   CREATE TABLE mymes.malfunction_types_t (
    malfunction_type_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
 &   DROP TABLE mymes.malfunction_types_t;
       mymes         cbtpost    false    5            �            1259    17077    malfunctions    TABLE     ~  CREATE TABLE mymes.malfunctions (
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
    DROP TABLE mymes.malfunctions;
       mymes         cbtpost    false    956    252    822    5            �            1259    17075    malfunctions_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.malfunctions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE mymes.malfunctions_id_seq;
       mymes       cbtpost    false    235    5            �           0    0    malfunctions_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE mymes.malfunctions_id_seq OWNED BY mymes.malfunctions.id;
            mymes       cbtpost    false    234            �            1259    17116    malfunctions_t    TABLE     �   CREATE TABLE mymes.malfunctions_t (
    description text NOT NULL,
    malfunction_id integer NOT NULL,
    lang_id integer NOT NULL
);
 !   DROP TABLE mymes.malfunctions_t;
       mymes         cbtpost    false    5            �            1259    17178 	   mnt_plans    TABLE       CREATE TABLE mymes.mnt_plans (
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
    DROP TABLE mymes.mnt_plans;
       mymes         cbtpost    false    5    252    956            �            1259    17176    mnt_plan_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.mnt_plan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE mymes.mnt_plan_id_seq;
       mymes       cbtpost    false    248    5            �           0    0    mnt_plan_id_seq    SEQUENCE OWNED BY     B   ALTER SEQUENCE mymes.mnt_plan_id_seq OWNED BY mymes.mnt_plans.id;
            mymes       cbtpost    false    247            �            1259    17187    mnt_plan_items    TABLE     �   CREATE TABLE mymes.mnt_plan_items (
    mnt_plan_id integer NOT NULL,
    resource_id integer NOT NULL,
    id integer NOT NULL
);
 !   DROP TABLE mymes.mnt_plan_items;
       mymes         cbtpost    false    5            �            1259    17196    mnt_plan_items_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.mnt_plan_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE mymes.mnt_plan_items_id_seq;
       mymes       cbtpost    false    249    5            �           0    0    mnt_plan_items_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE mymes.mnt_plan_items_id_seq OWNED BY mymes.mnt_plan_items.id;
            mymes       cbtpost    false    251            �            1259    17190    mnt_plans_t    TABLE     �   CREATE TABLE mymes.mnt_plans_t (
    mnt_plan_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
    DROP TABLE mymes.mnt_plans_t;
       mymes         cbtpost    false    5            '           1259    25582    notifications    TABLE       CREATE TABLE mymes.notifications (
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
     DROP TABLE mymes.notifications;
       mymes         admin    false    1057    5            &           1259    25580    notifications_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE mymes.notifications_id_seq;
       mymes       admin    false    5    295            �           0    0    notifications_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE mymes.notifications_id_seq OWNED BY mymes.notifications.id;
            mymes       admin    false    294            ?           1259    26927 
   numerators    TABLE     �   CREATE TABLE mymes.numerators (
    numerator integer NOT NULL,
    prefix text NOT NULL,
    row_type public.row_type NOT NULL,
    description text NOT NULL,
    id integer NOT NULL
);
    DROP TABLE mymes.numerators;
       mymes         admin    false    956    5            @           1259    27033    numerators_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.numerators_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE mymes.numerators_id_seq;
       mymes       admin    false    319    5            �           0    0    numerators_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE mymes.numerators_id_seq OWNED BY mymes.numerators.id;
            mymes       admin    false    320            �            1259    16868    part    TABLE     R  CREATE TABLE mymes.part (
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
    DROP TABLE mymes.part;
       mymes         cbtpost    false    956    5    252            �            1259    16866    part_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.part_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 !   DROP SEQUENCE mymes.part_id_seq;
       mymes       cbtpost    false    212    5            �           0    0    part_id_seq    SEQUENCE OWNED BY     9   ALTER SEQUENCE mymes.part_id_seq OWNED BY mymes.part.id;
            mymes       cbtpost    false    211            �            1259    16888    part_status    TABLE     �   CREATE TABLE mymes.part_status (
    id integer,
    name text,
    row_type public.row_type,
    tags text[],
    active boolean
)
INHERITS (mymes.tagable);
    DROP TABLE mymes.part_status;
       mymes         cbtpost    false    5    956    252            �            1259    16886    part_status_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.part_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE mymes.part_status_id_seq;
       mymes       cbtpost    false    5    215            �           0    0    part_status_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE mymes.part_status_id_seq OWNED BY mymes.part_status.id;
            mymes       cbtpost    false    214            �            1259    16894    part_status_t    TABLE     ~   CREATE TABLE mymes.part_status_t (
    part_status_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);
     DROP TABLE mymes.part_status_t;
       mymes         cbtpost    false    5            �            1259    16876    part_t    TABLE     p   CREATE TABLE mymes.part_t (
    part_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);
    DROP TABLE mymes.part_t;
       mymes         cbtpost    false    5            -           1259    26351 	   positions    TABLE     �   CREATE TABLE mymes.positions (
    id integer,
    name text,
    qa boolean,
    hr boolean,
    tags text[],
    row_type public.row_type NOT NULL,
    manager boolean
)
INHERITS (mymes.tagable);
    DROP TABLE mymes.positions;
       mymes         admin    false    252    956    5            ,           1259    26349    positions_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.positions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE mymes.positions_id_seq;
       mymes       admin    false    5    301            �           0    0    positions_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE mymes.positions_id_seq OWNED BY mymes.positions.id;
            mymes       admin    false    300            .           1259    26360    positions_t    TABLE     y   CREATE TABLE mymes.positions_t (
    position_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);
    DROP TABLE mymes.positions_t;
       mymes         admin    false    5            "           1259    25497    preferences    TABLE     q   CREATE TABLE mymes.preferences (
    id integer NOT NULL,
    name text,
    description text,
    value text
);
    DROP TABLE mymes.preferences;
       mymes         admin    false    5            !           1259    25495    preferences_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.preferences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE mymes.preferences_id_seq;
       mymes       admin    false    290    5                        0    0    preferences_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE mymes.preferences_id_seq OWNED BY mymes.preferences.id;
            mymes       admin    false    289                       1259    25327    proc_act    TABLE     �   CREATE TABLE mymes.proc_act (
    id integer NOT NULL,
    process_id integer,
    act_id integer,
    pos smallint,
    quantitative boolean,
    serialize boolean,
    batch boolean
);
    DROP TABLE mymes.proc_act;
       mymes         admin    false    5                       1259    25325    proc_act_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.proc_act_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE mymes.proc_act_id_seq;
       mymes       admin    false    5    276                       0    0    proc_act_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE mymes.proc_act_id_seq OWNED BY mymes.proc_act.id;
            mymes       admin    false    275                       1259    25304    process    TABLE     }   CREATE TABLE mymes.process (
    name text,
    id integer,
    erpproc text,
    active boolean
)
INHERITS (mymes.tagable);
    DROP TABLE mymes.process;
       mymes         admin    false    252    956    5                       1259    25302    process_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.process_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE mymes.process_id_seq;
       mymes       admin    false    273    5                       0    0    process_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE mymes.process_id_seq OWNED BY mymes.process.id;
            mymes       admin    false    272                       1259    25315 	   process_t    TABLE        CREATE TABLE mymes.process_t (
    process_id integer NOT NULL,
    description text NOT NULL,
    lang_id integer NOT NULL
);
    DROP TABLE mymes.process_t;
       mymes         admin    false    5            �            1259    17161    repair_types    TABLE     U   CREATE TABLE mymes.repair_types (
    id integer NOT NULL,
    name text NOT NULL
);
    DROP TABLE mymes.repair_types;
       mymes         cbtpost    false    5            �            1259    17159    repair_types_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.repair_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE mymes.repair_types_id_seq;
       mymes       cbtpost    false    5    245                       0    0    repair_types_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE mymes.repair_types_id_seq OWNED BY mymes.repair_types.id;
            mymes       cbtpost    false    244            �            1259    17170    repair_types_t    TABLE     �   CREATE TABLE mymes.repair_types_t (
    repair_type_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
 !   DROP TABLE mymes.repair_types_t;
       mymes         cbtpost    false    5            �            1259    17150    repairs    TABLE     H  CREATE TABLE mymes.repairs (
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
    DROP TABLE mymes.repairs;
       mymes         cbtpost    false    5    956    252            �            1259    17148    repairs_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.repairs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE mymes.repairs_id_seq;
       mymes       cbtpost    false    5    243                       0    0    repairs_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE mymes.repairs_id_seq OWNED BY mymes.repairs.id;
            mymes       cbtpost    false    242            *           1259    26313    resource_arc    TABLE     �   CREATE TABLE mymes.resource_arc (
    parent_id integer NOT NULL,
    son_id integer NOT NULL,
    ord smallint,
    id integer NOT NULL
);
    DROP TABLE mymes.resource_arc;
       mymes         admin    false    5            +           1259    26338    resource_arc_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.resource_arc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE mymes.resource_arc_id_seq;
       mymes       admin    false    298    5                       0    0    resource_arc_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE mymes.resource_arc_id_seq OWNED BY mymes.resource_arc.id;
            mymes       admin    false    299            �            1259    16626    resource_groups_t    TABLE     �   CREATE TABLE mymes.resource_groups_t (
    resource_group_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text,
    ws smallint
);
 $   DROP TABLE mymes.resource_groups_t;
       mymes         cbtpost    false    5            )           1259    26309    resource_desc    VIEW     �  CREATE VIEW mymes.resource_desc AS
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
    DROP VIEW mymes.resource_desc;
       mymes       admin    false    205    205    205    203    203    203    202    202    202    202    5            �            1259    16945    resource_groups    TABLE        CREATE TABLE mymes.resource_groups (
    resource_ids integer[],
    name text,
    extname text
)
INHERITS (mymes.resources);
 "   DROP TABLE mymes.resource_groups;
       mymes         cbtpost    false    956    5    218            1           1259    26422    resources_hierarchy    VIEW     /  CREATE VIEW mymes.resources_hierarchy AS
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
 %   DROP VIEW mymes.resources_hierarchy;
       mymes       admin    false    218    221    221    5            2           1259    26495    resource_level    VIEW     �   CREATE VIEW mymes.resource_level AS
 SELECT resources_hierarchy.parent AS resource,
    max(resources_hierarchy.depth) AS level
   FROM mymes.resources_hierarchy
  GROUP BY resources_hierarchy.parent
  ORDER BY (max(resources_hierarchy.depth)) DESC;
     DROP VIEW mymes.resource_level;
       mymes       admin    false    305    305    5            �            1259    16918    resources_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.resources_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE mymes.resources_id_seq;
       mymes       cbtpost    false    218    5                       0    0    resources_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE mymes.resources_id_seq OWNED BY mymes.resources.id;
            mymes       cbtpost    false    217                       1259    25343 
   serial_act    TABLE       CREATE TABLE mymes.serial_act (
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
    DROP TABLE mymes.serial_act;
       mymes         admin    false    5                       1259    25341    serial_act_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.serial_act_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE mymes.serial_act_id_seq;
       mymes       admin    false    278    5                       0    0    serial_act_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE mymes.serial_act_id_seq OWNED BY mymes.serial_act.id;
            mymes       admin    false    277            �            1259    16534    serial_seq_LANGUAGES_LANG    SEQUENCE     �   CREATE SEQUENCE mymes."serial_seq_LANGUAGES_LANG"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE mymes."serial_seq_LANGUAGES_LANG";
       mymes       cbtpost    false    5    198                       0    0    serial_seq_LANGUAGES_LANG    SEQUENCE OWNED BY     N   ALTER SEQUENCE mymes."serial_seq_LANGUAGES_LANG" OWNED BY mymes.languages.id;
            mymes       cbtpost    false    201                       1259    25256    serial_statuses    TABLE     �   CREATE TABLE mymes.serial_statuses (
    name text,
    id integer,
    active boolean,
    closed boolean,
    ext_status text
)
INHERITS (mymes.tagable);
 "   DROP TABLE mymes.serial_statuses;
       mymes         admin    false    956    252    5                       1259    25254    serial_statuses_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.serial_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE mymes.serial_statuses_id_seq;
       mymes       admin    false    5    268            	           0    0    serial_statuses_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE mymes.serial_statuses_id_seq OWNED BY mymes.serial_statuses.id;
            mymes       admin    false    267                       1259    25263    serial_statuses_t    TABLE     �   CREATE TABLE mymes.serial_statuses_t (
    serial_status_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
 $   DROP TABLE mymes.serial_statuses_t;
       mymes         admin    false    5                       1259    25185    serials    TABLE       CREATE TABLE mymes.serials (
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
    DROP TABLE mymes.serials;
       mymes         admin    false    5    956    252                       1259    25183    serials_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.serials_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE mymes.serials_id_seq;
       mymes       admin    false    258    5            
           0    0    serials_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE mymes.serials_id_seq OWNED BY mymes.serials.id;
            mymes       admin    false    257                       1259    25271 	   serials_t    TABLE     ~   CREATE TABLE mymes.serials_t (
    serial_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text NOT NULL
);
    DROP TABLE mymes.serials_t;
       mymes         admin    false    5            �            1259    17026 	   standards    TABLE     �   CREATE TABLE mymes.standards (
    id integer NOT NULL,
    name text NOT NULL,
    resource_id integer NOT NULL,
    quant integer NOT NULL,
    part_id integer,
    standard_type_id smallint,
    act_id integer
);
    DROP TABLE mymes.standards;
       mymes         cbtpost    false    5            �            1259    17024    standards_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.standards_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE mymes.standards_id_seq;
       mymes       cbtpost    false    230    5                       0    0    standards_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE mymes.standards_id_seq OWNED BY mymes.standards.id;
            mymes       cbtpost    false    229            �            1259    17037    standards_types    TABLE     O   CREATE TABLE mymes.standards_types (
    id integer NOT NULL,
    name text
);
 "   DROP TABLE mymes.standards_types;
       mymes         cbtpost    false    5            �            1259    17035    standards_types_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.standards_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE mymes.standards_types_id_seq;
       mymes       cbtpost    false    232    5                       0    0    standards_types_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE mymes.standards_types_id_seq OWNED BY mymes.standards_types.id;
            mymes       cbtpost    false    231            �            1259    17046    standards_types_t    TABLE     �   CREATE TABLE mymes.standards_types_t (
    lang_id integer NOT NULL,
    standard_type_id smallint NOT NULL,
    description text
);
 $   DROP TABLE mymes.standards_types_t;
       mymes         cbtpost    false    5            T           1259    27536    tables    TABLE     n   CREATE TABLE mymes.tables (
    id smallint NOT NULL,
    name text NOT NULL,
    row_type public.row_type
);
    DROP TABLE mymes.tables;
       mymes         admin    false    956    5            S           1259    27534    tables_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.tables_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE mymes.tables_id_seq;
       mymes       admin    false    5    340                       0    0    tables_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE mymes.tables_id_seq OWNED BY mymes.tables.id;
            mymes       admin    false    339                       1259    25446    work_report    TABLE     Z  CREATE TABLE mymes.work_report (
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
    DROP TABLE mymes.work_report;
       mymes         admin    false    956    5    317                       1259    25444    work_report_id_seq    SEQUENCE     �   CREATE SEQUENCE mymes.work_report_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE mymes.work_report_id_seq;
       mymes       admin    false    5    286                       0    0    work_report_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE mymes.work_report_id_seq OWNED BY mymes.work_report.id;
            mymes       admin    false    285            �            1259    16522    users    TABLE     �  CREATE TABLE public.users (
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
    DROP TABLE public.users;
       public         cbtpost    false    956            �            1259    16520    USERS_USERID_seq    SEQUENCE     �   CREATE SEQUENCE public."USERS_USERID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public."USERS_USERID_seq";
       public       cbtpost    false    200                       0    0    USERS_USERID_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE public."USERS_USERID_seq" OWNED BY public.users.id;
            public       cbtpost    false    199            �            1259    17229    bugs    TABLE     m   CREATE TABLE public.bugs (
    message text,
    id integer NOT NULL,
    status smallint,
    state text
);
    DROP TABLE public.bugs;
       public         cbtpost    false            �            1259    17227    bugs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.bugs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE public.bugs_id_seq;
       public       cbtpost    false    254                       0    0    bugs_id_seq    SEQUENCE OWNED BY     ;   ALTER SEQUENCE public.bugs_id_seq OWNED BY public.bugs.id;
            public       cbtpost    false    253            R           1259    27523    condition_type    TABLE     q   CREATE TABLE public.condition_type (
    condition public.condition_t NOT NULL,
    description text NOT NULL
);
 "   DROP TABLE public.condition_type;
       public         admin    false    1182            B           1259    27266    foreign_keys_view    VIEW     �  CREATE VIEW public.foreign_keys_view AS
 SELECT tc.table_name AS son_table,
    kcu.column_name AS son_column,
    ccu.table_name AS parent_table,
    ccu.column_name AS parent_column
   FROM ((information_schema.table_constraints tc
     JOIN information_schema.key_column_usage kcu ON ((((tc.constraint_name)::text = (kcu.constraint_name)::text) AND ((tc.table_schema)::text = (kcu.table_schema)::text))))
     JOIN information_schema.constraint_column_usage ccu ON ((((ccu.constraint_name)::text = (tc.constraint_name)::text) AND ((ccu.table_schema)::text = (tc.table_schema)::text))))
  WHERE (((tc.constraint_type)::text = 'FOREIGN KEY'::text) AND ((tc.table_schema)::text = 'mymes'::text));
 $   DROP VIEW public.foreign_keys_view;
       public       admin    false            �            1259    17135    profiles    TABLE     ]   CREATE TABLE public.profiles (
    id integer NOT NULL,
    name text,
    active boolean
);
    DROP TABLE public.profiles;
       public         cbtpost    false            �            1259    17133    profiles_id_seq    SEQUENCE     �   CREATE SEQUENCE public.profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.profiles_id_seq;
       public       cbtpost    false    240                       0    0    profiles_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE public.profiles_id_seq OWNED BY public.profiles.id;
            public       cbtpost    false    239            �            1259    25167 
   profiles_t    TABLE     x   CREATE TABLE public.profiles_t (
    profile_id integer NOT NULL,
    lang_id integer NOT NULL,
    description text
);
    DROP TABLE public.profiles_t;
       public         admin    false                        1259    25173    routes    TABLE     0   CREATE TABLE public.routes (
    routes text
);
    DROP TABLE public.routes;
       public         admin    false            K           1259    27420    sn    TABLE     *   CREATE TABLE public.sn (
    name text
);
    DROP TABLE public.sn;
       public         admin    false            (           1259    26229    tagable    TABLE     ^   CREATE TABLE public.tagable (
    tags text[],
    row_type public.row_type,
    name text
);
    DROP TABLE public.tagable;
       public         admin    false    956            A           1259    27064    test    TABLE     k   CREATE TABLE public.test (
    ts_naked timestamp without time zone,
    ts_tz timestamp with time zone
);
    DROP TABLE public.test;
       public         admin    false            %           1259    25555    tmp    TABLE     �   CREATE TABLE public.tmp (
    from_date timestamp(6) with time zone,
    to_date timestamp(6) with time zone,
    flag_o boolean
);
    DROP TABLE public.tmp;
       public         admin    false            L           1259    27434    debug    TABLE     +   CREATE TABLE test.debug (
    text text
);
    DROP TABLE test.debug;
       test         admin    false    4            8           2604    16968     utilization id    DEFAULT     t   ALTER TABLE ONLY mymes." utilization" ALTER COLUMN id SET DEFAULT nextval('mymes." utilization_id_seq"'::regclass);
 ?   ALTER TABLE mymes." utilization" ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    226    225    226            W           2604    26391    act_resources id    DEFAULT     r   ALTER TABLE ONLY mymes.act_resources ALTER COLUMN id SET DEFAULT nextval('mymes.act_resources_id_seq'::regclass);
 >   ALTER TABLE mymes.act_resources ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    303    304    304            F           2604    25210 
   actions id    DEFAULT     f   ALTER TABLE ONLY mymes.actions ALTER COLUMN id SET DEFAULT nextval('mymes.actions_id_seq'::regclass);
 8   ALTER TABLE mymes.actions ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    261    260    261            7           2604    17017    availabilities id    DEFAULT     t   ALTER TABLE ONLY mymes.availabilities ALTER COLUMN id SET DEFAULT nextval('mymes.availabilities_id_seq'::regclass);
 ?   ALTER TABLE mymes.availabilities ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    228    224            6           2604    16957    availability_profiles id    DEFAULT     �   ALTER TABLE ONLY mymes.availability_profiles ALTER COLUMN id SET DEFAULT nextval('mymes.availability_profile_id_seq'::regclass);
 F   ALTER TABLE mymes.availability_profiles ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    222    223    223            M           2604    25371    bom id    DEFAULT     ^   ALTER TABLE ONLY mymes.bom ALTER COLUMN id SET DEFAULT nextval('mymes.bom_id_seq'::regclass);
 4   ALTER TABLE mymes.bom ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    280    279    280            #           2604    16839    departments id    DEFAULT     n   ALTER TABLE ONLY mymes.departments ALTER COLUMN id SET DEFAULT nextval('mymes.departments_id_seq'::regclass);
 <   ALTER TABLE mymes.departments ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    208    209    209            *           2604    16929    employees id    DEFAULT     j   ALTER TABLE ONLY mymes.employees ALTER COLUMN id SET DEFAULT nextval('mymes.resources_id_seq'::regclass);
 :   ALTER TABLE mymes.employees ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    219    217            +           2604    16975    employees level    DEFAULT     C   ALTER TABLE ONLY mymes.employees ALTER COLUMN level SET DEFAULT 0;
 =   ALTER TABLE mymes.employees ALTER COLUMN level DROP DEFAULT;
       mymes       cbtpost    false    219            ,           2604    17062    employees tags    DEFAULT     P   ALTER TABLE ONLY mymes.employees ALTER COLUMN tags SET DEFAULT ARRAY[]::text[];
 <   ALTER TABLE mymes.employees ALTER COLUMN tags DROP DEFAULT;
       mymes       cbtpost    false    219            0           2604    16933    equipments id    DEFAULT     k   ALTER TABLE ONLY mymes.equipments ALTER COLUMN id SET DEFAULT nextval('mymes.resources_id_seq'::regclass);
 ;   ALTER TABLE mymes.equipments ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    217    220            1           2604    16976    equipments level    DEFAULT     D   ALTER TABLE ONLY mymes.equipments ALTER COLUMN level SET DEFAULT 0;
 >   ALTER TABLE mymes.equipments ALTER COLUMN level DROP DEFAULT;
       mymes       cbtpost    false    220            2           2604    17063    equipments tags    DEFAULT     Q   ALTER TABLE ONLY mymes.equipments ALTER COLUMN tags SET DEFAULT ARRAY[]::text[];
 =   ALTER TABLE mymes.equipments ALTER COLUMN tags DROP DEFAULT;
       mymes       cbtpost    false    220            c           2604    27491    event_triggers id    DEFAULT     l   ALTER TABLE ONLY mymes.event_triggers ALTER COLUMN id SET DEFAULT nextval('mymes.checks_id_seq'::regclass);
 ?   ALTER TABLE mymes.event_triggers ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    336    337    337            Z           2604    26839    fault id    DEFAULT     a   ALTER TABLE ONLY mymes.fault ALTER COLUMN id SET DEFAULT nextval('mymes.malf_id_seq'::regclass);
 6   ALTER TABLE mymes.fault ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    312    313    313            Y           2604    26545    fault_status id    DEFAULT     o   ALTER TABLE ONLY mymes.fault_status ALTER COLUMN id SET DEFAULT nextval('mymes.malf_status_id_seq'::regclass);
 =   ALTER TABLE mymes.fault_status ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    310    311    311            X           2604    26521    fault_type id    DEFAULT     k   ALTER TABLE ONLY mymes.fault_type ALTER COLUMN id SET DEFAULT nextval('mymes.malf_type_id_seq'::regclass);
 ;   ALTER TABLE mymes.fault_type ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    309    308    309            ^           2604    27289    fault_type_act id    DEFAULT     t   ALTER TABLE ONLY mymes.fault_type_act ALTER COLUMN id SET DEFAULT nextval('mymes.fault_type_act_id_seq'::regclass);
 ?   ALTER TABLE mymes.fault_type_act ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    324    323            _           2604    27344    fix id    DEFAULT     ^   ALTER TABLE ONLY mymes.fix ALTER COLUMN id SET DEFAULT nextval('mymes.fix_id_seq'::regclass);
 4   ALTER TABLE mymes.fix ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    326    325    326            a           2604    27386 
   fix_act id    DEFAULT     f   ALTER TABLE ONLY mymes.fix_act ALTER COLUMN id SET DEFAULT nextval('mymes.fix_act_id_seq'::regclass);
 8   ALTER TABLE mymes.fix_act ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    329    330    330            `           2604    27359    fix_t fix_id    DEFAULT     j   ALTER TABLE ONLY mymes.fix_t ALTER COLUMN fix_id SET DEFAULT nextval('mymes.fix_t_fix_id_seq'::regclass);
 :   ALTER TABLE mymes.fix_t ALTER COLUMN fix_id DROP DEFAULT;
       mymes       admin    false    327    328    328            P           2604    25481    identifier id    DEFAULT     m   ALTER TABLE ONLY mymes.identifier ALTER COLUMN id SET DEFAULT nextval('mymes.identifiers_id_seq'::regclass);
 ;   ALTER TABLE mymes.identifier ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    287    288    288            \           2604    35800    identifier_links id    DEFAULT     x   ALTER TABLE ONLY mymes.identifier_links ALTER COLUMN id SET DEFAULT nextval('mymes.identifier_links_id_seq'::regclass);
 A   ALTER TABLE mymes.identifier_links ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    341    318            H           2604    25240    import_schemas id    DEFAULT     t   ALTER TABLE ONLY mymes.import_schemas ALTER COLUMN id SET DEFAULT nextval('mymes.import_schemas_id_seq'::regclass);
 ?   ALTER TABLE mymes.import_schemas ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    264    265    265            G           2604    26741    kit id    DEFAULT     ^   ALTER TABLE ONLY mymes.kit ALTER COLUMN id SET DEFAULT nextval('mymes.kit_id_seq'::regclass);
 4   ALTER TABLE mymes.kit ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    281    263                        2604    16536    languages id    DEFAULT     u   ALTER TABLE ONLY mymes.languages ALTER COLUMN id SET DEFAULT nextval('mymes."serial_seq_LANGUAGES_LANG"'::regclass);
 :   ALTER TABLE mymes.languages ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    201    198            N           2604    25413    local_actions id    DEFAULT     r   ALTER TABLE ONLY mymes.local_actions ALTER COLUMN id SET DEFAULT nextval('mymes.local_actions_id_seq'::regclass);
 >   ALTER TABLE mymes.local_actions ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    283    282    283            E           2604    26731    locations id    DEFAULT     j   ALTER TABLE ONLY mymes.locations ALTER COLUMN id SET DEFAULT nextval('mymes.locations_id_seq'::regclass);
 :   ALTER TABLE mymes.locations ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    271    259            b           2604    27468    lot_swap id    DEFAULT     h   ALTER TABLE ONLY mymes.lot_swap ALTER COLUMN id SET DEFAULT nextval('mymes.lot_swap_id_seq'::regclass);
 9   ALTER TABLE mymes.lot_swap ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    335    334            =           2604    17110    malfunction_types id    DEFAULT     z   ALTER TABLE ONLY mymes.malfunction_types ALTER COLUMN id SET DEFAULT nextval('mymes.malfunction_types_id_seq'::regclass);
 B   ALTER TABLE mymes.malfunction_types ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    236    237    237            ;           2604    17080    malfunctions id    DEFAULT     p   ALTER TABLE ONLY mymes.malfunctions ALTER COLUMN id SET DEFAULT nextval('mymes.malfunctions_id_seq'::regclass);
 =   ALTER TABLE mymes.malfunctions ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    235    234    235            B           2604    17198    mnt_plan_items id    DEFAULT     t   ALTER TABLE ONLY mymes.mnt_plan_items ALTER COLUMN id SET DEFAULT nextval('mymes.mnt_plan_items_id_seq'::regclass);
 ?   ALTER TABLE mymes.mnt_plan_items ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    251    249            A           2604    17181    mnt_plans id    DEFAULT     i   ALTER TABLE ONLY mymes.mnt_plans ALTER COLUMN id SET DEFAULT nextval('mymes.mnt_plan_id_seq'::regclass);
 :   ALTER TABLE mymes.mnt_plans ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    247    248    248            T           2604    25585    notifications id    DEFAULT     r   ALTER TABLE ONLY mymes.notifications ALTER COLUMN id SET DEFAULT nextval('mymes.notifications_id_seq'::regclass);
 >   ALTER TABLE mymes.notifications ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    294    295    295            ]           2604    27035    numerators id    DEFAULT     l   ALTER TABLE ONLY mymes.numerators ALTER COLUMN id SET DEFAULT nextval('mymes.numerators_id_seq'::regclass);
 ;   ALTER TABLE mymes.numerators ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    320    319            $           2604    16871    part id    DEFAULT     `   ALTER TABLE ONLY mymes.part ALTER COLUMN id SET DEFAULT nextval('mymes.part_id_seq'::regclass);
 5   ALTER TABLE mymes.part ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    212    211    212            &           2604    16891    part_status id    DEFAULT     n   ALTER TABLE ONLY mymes.part_status ALTER COLUMN id SET DEFAULT nextval('mymes.part_status_id_seq'::regclass);
 <   ALTER TABLE mymes.part_status ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    215    214    215            "           2604    16699    permissions id    DEFAULT     w   ALTER TABLE ONLY mymes.permissions ALTER COLUMN id SET DEFAULT nextval('mymes."PERMISSIONS_PERMISION_seq"'::regclass);
 <   ALTER TABLE mymes.permissions ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    206    204            V           2604    26354    positions id    DEFAULT     j   ALTER TABLE ONLY mymes.positions ALTER COLUMN id SET DEFAULT nextval('mymes.positions_id_seq'::regclass);
 :   ALTER TABLE mymes.positions ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    300    301    301            R           2604    25500    preferences id    DEFAULT     n   ALTER TABLE ONLY mymes.preferences ALTER COLUMN id SET DEFAULT nextval('mymes.preferences_id_seq'::regclass);
 <   ALTER TABLE mymes.preferences ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    289    290    290            K           2604    25330    proc_act id    DEFAULT     h   ALTER TABLE ONLY mymes.proc_act ALTER COLUMN id SET DEFAULT nextval('mymes.proc_act_id_seq'::regclass);
 9   ALTER TABLE mymes.proc_act ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    275    276    276            J           2604    25307 
   process id    DEFAULT     f   ALTER TABLE ONLY mymes.process ALTER COLUMN id SET DEFAULT nextval('mymes.process_id_seq'::regclass);
 8   ALTER TABLE mymes.process ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    272    273    273            @           2604    17164    repair_types id    DEFAULT     p   ALTER TABLE ONLY mymes.repair_types ALTER COLUMN id SET DEFAULT nextval('mymes.repair_types_id_seq'::regclass);
 =   ALTER TABLE mymes.repair_types ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    245    244    245            ?           2604    17153 
   repairs id    DEFAULT     f   ALTER TABLE ONLY mymes.repairs ALTER COLUMN id SET DEFAULT nextval('mymes.repairs_id_seq'::regclass);
 8   ALTER TABLE mymes.repairs ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    242    243    243            U           2604    26340    resource_arc id    DEFAULT     p   ALTER TABLE ONLY mymes.resource_arc ALTER COLUMN id SET DEFAULT nextval('mymes.resource_arc_id_seq'::regclass);
 =   ALTER TABLE mymes.resource_arc ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    299    298            3           2604    16948    resource_groups id    DEFAULT     p   ALTER TABLE ONLY mymes.resource_groups ALTER COLUMN id SET DEFAULT nextval('mymes.resources_id_seq'::regclass);
 @   ALTER TABLE mymes.resource_groups ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    221    217            4           2604    16977    resource_groups level    DEFAULT     I   ALTER TABLE ONLY mymes.resource_groups ALTER COLUMN level SET DEFAULT 0;
 C   ALTER TABLE mymes.resource_groups ALTER COLUMN level DROP DEFAULT;
       mymes       cbtpost    false    221            5           2604    17064    resource_groups tags    DEFAULT     V   ALTER TABLE ONLY mymes.resource_groups ALTER COLUMN tags SET DEFAULT ARRAY[]::text[];
 B   ALTER TABLE mymes.resource_groups ALTER COLUMN tags DROP DEFAULT;
       mymes       cbtpost    false    221            S           2604    25531    resource_timeoff id    DEFAULT     s   ALTER TABLE ONLY mymes.resource_timeoff ALTER COLUMN id SET DEFAULT nextval('mymes.ap_holidays_id_seq'::regclass);
 A   ALTER TABLE mymes.resource_timeoff ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    291    292    292            '           2604    16923    resources id    DEFAULT     j   ALTER TABLE ONLY mymes.resources ALTER COLUMN id SET DEFAULT nextval('mymes.resources_id_seq'::regclass);
 :   ALTER TABLE mymes.resources ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    217    218    218            L           2604    25346    serial_act id    DEFAULT     l   ALTER TABLE ONLY mymes.serial_act ALTER COLUMN id SET DEFAULT nextval('mymes.serial_act_id_seq'::regclass);
 ;   ALTER TABLE mymes.serial_act ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    277    278    278            I           2604    25259    serial_statuses id    DEFAULT     v   ALTER TABLE ONLY mymes.serial_statuses ALTER COLUMN id SET DEFAULT nextval('mymes.serial_statuses_id_seq'::regclass);
 @   ALTER TABLE mymes.serial_statuses ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    268    267    268            D           2604    25188 
   serials id    DEFAULT     f   ALTER TABLE ONLY mymes.serials ALTER COLUMN id SET DEFAULT nextval('mymes.serials_id_seq'::regclass);
 8   ALTER TABLE mymes.serials ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    258    257    258            9           2604    17029    standards id    DEFAULT     j   ALTER TABLE ONLY mymes.standards ALTER COLUMN id SET DEFAULT nextval('mymes.standards_id_seq'::regclass);
 :   ALTER TABLE mymes.standards ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    229    230    230            :           2604    17040    standards_types id    DEFAULT     v   ALTER TABLE ONLY mymes.standards_types ALTER COLUMN id SET DEFAULT nextval('mymes.standards_types_id_seq'::regclass);
 @   ALTER TABLE mymes.standards_types ALTER COLUMN id DROP DEFAULT;
       mymes       cbtpost    false    232    231    232            d           2604    27539 	   tables id    DEFAULT     d   ALTER TABLE ONLY mymes.tables ALTER COLUMN id SET DEFAULT nextval('mymes.tables_id_seq'::regclass);
 7   ALTER TABLE mymes.tables ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    340    339    340            O           2604    26823    work_report id    DEFAULT     n   ALTER TABLE ONLY mymes.work_report ALTER COLUMN id SET DEFAULT nextval('mymes.work_report_id_seq'::regclass);
 <   ALTER TABLE mymes.work_report ALTER COLUMN id DROP DEFAULT;
       mymes       admin    false    286    285    286            C           2604    17232    bugs id    DEFAULT     b   ALTER TABLE ONLY public.bugs ALTER COLUMN id SET DEFAULT nextval('public.bugs_id_seq'::regclass);
 6   ALTER TABLE public.bugs ALTER COLUMN id DROP DEFAULT;
       public       cbtpost    false    253    254    254            >           2604    17138    profiles id    DEFAULT     j   ALTER TABLE ONLY public.profiles ALTER COLUMN id SET DEFAULT nextval('public.profiles_id_seq'::regclass);
 :   ALTER TABLE public.profiles ALTER COLUMN id DROP DEFAULT;
       public       cbtpost    false    239    240    240            !           2604    16525    users id    DEFAULT     j   ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public."USERS_USERID_seq"'::regclass);
 7   ALTER TABLE public.users ALTER COLUMN id DROP DEFAULT;
       public       cbtpost    false    200    199    200            i          0    16965     utilization 
   TABLE DATA                     mymes       cbtpost    false    226   ��      �          0    26388    act_resources 
   TABLE DATA                     mymes       admin    false    304   ��      �          0    25207    actions 
   TABLE DATA                     mymes       admin    false    261   ��      �          0    25216 	   actions_t 
   TABLE DATA                     mymes       admin    false    262   ��      g          0    16960    availabilities 
   TABLE DATA                     mymes       cbtpost    false    224   �      f          0    16954    availability_profiles 
   TABLE DATA                     mymes       cbtpost    false    223   ��      j          0    16997    availability_profiles_t 
   TABLE DATA                     mymes       cbtpost    false    227   ~�      �          0    25368    bom 
   TABLE DATA                     mymes       admin    false    280   ��      Y          0    16858    configurations 
   TABLE DATA                     mymes       cbtpost    false    210   ��      �          0    26502    convers 
   TABLE DATA                     mymes       admin    false    307   ��      X          0    16836    departments 
   TABLE DATA                     mymes       cbtpost    false    209   ��      V          0    16831    departments_t 
   TABLE DATA                     mymes       cbtpost    false    207   ��      b          0    16926 	   employees 
   TABLE DATA                     mymes       cbtpost    false    219   ��      Q          0    16540    employees_t 
   TABLE DATA                     mymes       cbtpost    false    202   ��      c          0    16930 
   equipments 
   TABLE DATA                     mymes       cbtpost    false    220   ��      R          0    16543    equipments_t 
   TABLE DATA                     mymes       cbtpost    false    203   }�      �          0    27488    event_triggers 
   TABLE DATA                     mymes       admin    false    337   ��      �          0    26557    fault 
   TABLE DATA                     mymes       admin    false    313   �      �          0    26542    fault_status 
   TABLE DATA                     mymes       admin    false    311   �      �          0    26575    fault_status_t 
   TABLE DATA                     mymes       admin    false    315   �      �          0    26581    fault_t 
   TABLE DATA                     mymes       admin    false    316   *      �          0    26518 
   fault_type 
   TABLE DATA                     mymes       admin    false    309   
      �          0    27277    fault_type_act 
   TABLE DATA                     mymes       admin    false    323   �
      �          0    26569    fault_type_t 
   TABLE DATA                     mymes       admin    false    314   �      �          0    27341    fix 
   TABLE DATA                     mymes       admin    false    326   >      �          0    27383    fix_act 
   TABLE DATA                     mymes       admin    false    330   u      �          0    27356    fix_t 
   TABLE DATA                     mymes       admin    false    328         �          0    25478 
   identifier 
   TABLE DATA                     mymes       admin    false    288   �      �          0    26693    identifier_links 
   TABLE DATA                     mymes       admin    false    318   �K      �          0    25246    import_schamas_t 
   TABLE DATA                     mymes       admin    false    266   ח      �          0    25237    import_schemas 
   TABLE DATA                     mymes       admin    false    265   �      �          0    25227    kit 
   TABLE DATA                     mymes       admin    false    263   �      �          0    27449 	   kit_usage 
   TABLE DATA                     mymes       admin    false    333   ��      M          0    16470 	   languages 
   TABLE DATA                     mymes       cbtpost    false    198   ��      �          0    25410    local_actions 
   TABLE DATA                     mymes       admin    false    283   ]�      �          0    25431    local_actions_t 
   TABLE DATA                     mymes       admin    false    284   w�      �          0    25192 	   locations 
   TABLE DATA                     mymes       admin    false    259   ��      �          0    27454    lot_swap 
   TABLE DATA                     mymes       admin    false    334   �k      t          0    17107    malfunction_types 
   TABLE DATA                     mymes       cbtpost    false    237    m      x          0    17142    malfunction_types_t 
   TABLE DATA                     mymes       cbtpost    false    241   �m      r          0    17077    malfunctions 
   TABLE DATA                     mymes       cbtpost    false    235   �n      u          0    17116    malfunctions_t 
   TABLE DATA                     mymes       cbtpost    false    238   �o      �          0    17187    mnt_plan_items 
   TABLE DATA                     mymes       cbtpost    false    249   �p                0    17178 	   mnt_plans 
   TABLE DATA                     mymes       cbtpost    false    248   .q      �          0    17190    mnt_plans_t 
   TABLE DATA                     mymes       cbtpost    false    250   -r      �          0    25582    notifications 
   TABLE DATA                     mymes       admin    false    295   �r      �          0    26927 
   numerators 
   TABLE DATA                     mymes       admin    false    319   Ё      [          0    16868    part 
   TABLE DATA                     mymes       cbtpost    false    212   &�      ^          0    16888    part_status 
   TABLE DATA                     mymes       cbtpost    false    215   <�      _          0    16894    part_status_t 
   TABLE DATA                     mymes       cbtpost    false    216   �      \          0    16876    part_t 
   TABLE DATA                     mymes       cbtpost    false    213   ��      S          0    16557    permissions 
   TABLE DATA                     mymes       cbtpost    false    204   ��      �          0    26351 	   positions 
   TABLE DATA                     mymes       admin    false    301   ��      �          0    26360    positions_t 
   TABLE DATA                     mymes       admin    false    302   R�      �          0    25497    preferences 
   TABLE DATA                     mymes       admin    false    290   ��      �          0    25327    proc_act 
   TABLE DATA                     mymes       admin    false    276   ��      �          0    25304    process 
   TABLE DATA                     mymes       admin    false    273   ��      �          0    25315 	   process_t 
   TABLE DATA                     mymes       admin    false    274   ��      |          0    17161    repair_types 
   TABLE DATA                     mymes       cbtpost    false    245   {�      }          0    17170    repair_types_t 
   TABLE DATA                     mymes       cbtpost    false    246   �      z          0    17150    repairs 
   TABLE DATA                     mymes       cbtpost    false    243   ��      �          0    26313    resource_arc 
   TABLE DATA                     mymes       admin    false    298   ��      d          0    16945    resource_groups 
   TABLE DATA                     mymes       cbtpost    false    221   �      T          0    16626    resource_groups_t 
   TABLE DATA                     mymes       cbtpost    false    205   -�      �          0    25528    resource_timeoff 
   TABLE DATA                     mymes       admin    false    292   3�      a          0    16920 	   resources 
   TABLE DATA                     mymes       cbtpost    false    218   |�      �          0    26688    sendable 
   TABLE DATA                     mymes       admin    false    317   ��      �          0    25343 
   serial_act 
   TABLE DATA                     mymes       admin    false    278   ��      �          0    25256    serial_statuses 
   TABLE DATA                     mymes       admin    false    268   <�      �          0    25263    serial_statuses_t 
   TABLE DATA                     mymes       admin    false    269   
�      �          0    25185    serials 
   TABLE DATA                     mymes       admin    false    258   ��      �          0    25271 	   serials_t 
   TABLE DATA                     mymes       admin    false    270   S�      m          0    17026 	   standards 
   TABLE DATA                     mymes       cbtpost    false    230   �      o          0    17037    standards_types 
   TABLE DATA                     mymes       cbtpost    false    232   �      p          0    17046    standards_types_t 
   TABLE DATA                     mymes       cbtpost    false    233   8�      �          0    27536    tables 
   TABLE DATA                     mymes       admin    false    340   R�      �          0    17215    tagable 
   TABLE DATA                     mymes       cbtpost    false    252   ��      �          0    25446    work_report 
   TABLE DATA                     mymes       admin    false    286   ׾      �          0    17229    bugs 
   TABLE DATA                     public       cbtpost    false    254   ?�      �          0    27523    condition_type 
   TABLE DATA                     public       admin    false    338   ��      w          0    17135    profiles 
   TABLE DATA                     public       cbtpost    false    240   ��      �          0    25167 
   profiles_t 
   TABLE DATA                     public       admin    false    255   V�      �          0    25173    routes 
   TABLE DATA                     public       admin    false    256   0�      �          0    27420    sn 
   TABLE DATA                     public       admin    false    331   +�      �          0    26229    tagable 
   TABLE DATA                     public       admin    false    296   E�      �          0    27064    test 
   TABLE DATA                     public       admin    false    321   _�      �          0    25555    tmp 
   TABLE DATA                     public       admin    false    293   ��      O          0    16522    users 
   TABLE DATA                     public       cbtpost    false    200   x�      �          0    27434    debug 
   TABLE DATA                     test       admin    false    332   �                 0    0     utilization_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('mymes." utilization_id_seq"', 1, false);
            mymes       cbtpost    false    225                       0    0    PERMISSIONS_PERMISION_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('mymes."PERMISSIONS_PERMISION_seq"', 1, false);
            mymes       cbtpost    false    206                       0    0    act_resources_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('mymes.act_resources_id_seq', 503, true);
            mymes       admin    false    303                       0    0    actions_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('mymes.actions_id_seq', 99, true);
            mymes       admin    false    260                       0    0    ap_holidays_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('mymes.ap_holidays_id_seq', 246, true);
            mymes       admin    false    291                       0    0    availabilities_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('mymes.availabilities_id_seq', 170, true);
            mymes       cbtpost    false    228                       0    0    availability_profile_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('mymes.availability_profile_id_seq', 27, true);
            mymes       cbtpost    false    222                       0    0 
   bom_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('mymes.bom_id_seq', 3460, true);
            mymes       admin    false    279                       0    0    checks_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('mymes.checks_id_seq', 82, true);
            mymes       admin    false    336                       0    0    departments_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('mymes.departments_id_seq', 9, true);
            mymes       cbtpost    false    208                       0    0    fault_type_act_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('mymes.fault_type_act_id_seq', 16, true);
            mymes       admin    false    324                       0    0    fix_act_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('mymes.fix_act_id_seq', 13, true);
            mymes       admin    false    329                       0    0 
   fix_id_seq    SEQUENCE SET     8   SELECT pg_catalog.setval('mymes.fix_id_seq', 61, true);
            mymes       admin    false    325                       0    0    fix_t_fix_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('mymes.fix_t_fix_id_seq', 1, false);
            mymes       admin    false    327                        0    0    identifier_links_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('mymes.identifier_links_id_seq', 2421, true);
            mymes       admin    false    341            !           0    0    identifiers_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('mymes.identifiers_id_seq', 5630, true);
            mymes       admin    false    287            "           0    0    import_schemas_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('mymes.import_schemas_id_seq', 1, false);
            mymes       admin    false    264            #           0    0 
   kit_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('mymes.kit_id_seq', 2724, true);
            mymes       admin    false    281            $           0    0    local_actions_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('mymes.local_actions_id_seq', 1, false);
            mymes       admin    false    282            %           0    0    locations_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('mymes.locations_id_seq', 13314, true);
            mymes       admin    false    271            &           0    0    lot_swap_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('mymes.lot_swap_id_seq', 9, true);
            mymes       admin    false    335            '           0    0    malf_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('mymes.malf_id_seq', 142, true);
            mymes       admin    false    312            (           0    0    malf_status_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('mymes.malf_status_id_seq', 3, true);
            mymes       admin    false    310            )           0    0    malf_type_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('mymes.malf_type_id_seq', 167, true);
            mymes       admin    false    308            *           0    0    malfunction_types_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('mymes.malfunction_types_id_seq', 5, true);
            mymes       cbtpost    false    236            +           0    0    malfunctions_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('mymes.malfunctions_id_seq', 4, true);
            mymes       cbtpost    false    234            ,           0    0    mnt_plan_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('mymes.mnt_plan_id_seq', 3, true);
            mymes       cbtpost    false    247            -           0    0    mnt_plan_items_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('mymes.mnt_plan_items_id_seq', 46, true);
            mymes       cbtpost    false    251            .           0    0    notifications_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('mymes.notifications_id_seq', 4160, true);
            mymes       admin    false    294            /           0    0    numerators_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('mymes.numerators_id_seq', 23, true);
            mymes       admin    false    320            0           0    0    part_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('mymes.part_id_seq', 209, true);
            mymes       cbtpost    false    211            1           0    0    part_status_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('mymes.part_status_id_seq', 7, true);
            mymes       cbtpost    false    214            2           0    0    positions_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('mymes.positions_id_seq', 3, true);
            mymes       admin    false    300            3           0    0    preferences_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('mymes.preferences_id_seq', 6, true);
            mymes       admin    false    289            4           0    0    proc_act_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('mymes.proc_act_id_seq', 264, true);
            mymes       admin    false    275            5           0    0    process_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('mymes.process_id_seq', 60, true);
            mymes       admin    false    272            6           0    0    repair_types_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('mymes.repair_types_id_seq', 4, true);
            mymes       cbtpost    false    244            7           0    0    repairs_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('mymes.repairs_id_seq', 9, true);
            mymes       cbtpost    false    242            8           0    0    resource_arc_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('mymes.resource_arc_id_seq', 35, true);
            mymes       admin    false    299            9           0    0    resources_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('mymes.resources_id_seq', 167, true);
            mymes       cbtpost    false    217            :           0    0    serial_act_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('mymes.serial_act_id_seq', 478, true);
            mymes       admin    false    277            ;           0    0    serial_seq_LANGUAGES_LANG    SEQUENCE SET     H   SELECT pg_catalog.setval('mymes."serial_seq_LANGUAGES_LANG"', 3, true);
            mymes       cbtpost    false    201            <           0    0    serial_statuses_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('mymes.serial_statuses_id_seq', 9, true);
            mymes       admin    false    267            =           0    0    serials_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('mymes.serials_id_seq', 216, true);
            mymes       admin    false    257            >           0    0    standards_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('mymes.standards_id_seq', 1, false);
            mymes       cbtpost    false    229            ?           0    0    standards_types_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('mymes.standards_types_id_seq', 1, false);
            mymes       cbtpost    false    231            @           0    0    tables_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('mymes.tables_id_seq', 1, true);
            mymes       admin    false    339            A           0    0    work_report_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('mymes.work_report_id_seq', 1544, true);
            mymes       admin    false    285            B           0    0    USERS_USERID_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public."USERS_USERID_seq"', 46, true);
            public       cbtpost    false    199            C           0    0    bugs_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.bugs_id_seq', 26, true);
            public       cbtpost    false    253            D           0    0    profiles_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.profiles_id_seq', 7, true);
            public       cbtpost    false    239            �           2606    16973     utilization  utilization_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY mymes." utilization"
    ADD CONSTRAINT " utilization_pkey" PRIMARY KEY (id);
 K   ALTER TABLE ONLY mymes." utilization" DROP CONSTRAINT " utilization_pkey";
       mymes         cbtpost    false    226            f           2606    16816    languages LANGUAGES_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY mymes.languages
    ADD CONSTRAINT "LANGUAGES_pkey" PRIMARY KEY (id);
 C   ALTER TABLE ONLY mymes.languages DROP CONSTRAINT "LANGUAGES_pkey";
       mymes         cbtpost    false    198            h           2606    16814    languages LANG_NAME_key 
   CONSTRAINT     S   ALTER TABLE ONLY mymes.languages
    ADD CONSTRAINT "LANG_NAME_key" UNIQUE (name);
 B   ALTER TABLE ONLY mymes.languages DROP CONSTRAINT "LANG_NAME_key";
       mymes         cbtpost    false    198            o           2606    16801    permissions PERMISSIONS_pkey 
   CONSTRAINT     [   ALTER TABLE ONLY mymes.permissions
    ADD CONSTRAINT "PERMISSIONS_pkey" PRIMARY KEY (id);
 G   ALTER TABLE ONLY mymes.permissions DROP CONSTRAINT "PERMISSIONS_pkey";
       mymes         cbtpost    false    204            q           2606    16778 "   resource_groups_t RESOURCES_T_pkey 
   CONSTRAINT     y   ALTER TABLE ONLY mymes.resource_groups_t
    ADD CONSTRAINT "RESOURCES_T_pkey" PRIMARY KEY (lang_id, resource_group_id);
 M   ALTER TABLE ONLY mymes.resource_groups_t DROP CONSTRAINT "RESOURCES_T_pkey";
       mymes         cbtpost    false    205    205                       2606    26397     act_resources act_resources_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY mymes.act_resources
    ADD CONSTRAINT act_resources_pkey PRIMARY KEY (act_id, resource_id, type);
 I   ALTER TABLE ONLY mymes.act_resources DROP CONSTRAINT act_resources_pkey;
       mymes         admin    false    304    304    304            	           2606    26402 7   act_resources act_resources_resource_id_act_id_type_key 
   CONSTRAINT     �   ALTER TABLE ONLY mymes.act_resources
    ADD CONSTRAINT act_resources_resource_id_act_id_type_key UNIQUE (resource_id, act_id, type);
 `   ALTER TABLE ONLY mymes.act_resources DROP CONSTRAINT act_resources_resource_id_act_id_type_key;
       mymes         admin    false    304    304    304            �           2606    26433    actions actions_name_key 
   CONSTRAINT     R   ALTER TABLE ONLY mymes.actions
    ADD CONSTRAINT actions_name_key UNIQUE (name);
 A   ALTER TABLE ONLY mymes.actions DROP CONSTRAINT actions_name_key;
       mymes         admin    false    261            �           2606    25215    actions actions_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY mymes.actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (id);
 =   ALTER TABLE ONLY mymes.actions DROP CONSTRAINT actions_pkey;
       mymes         admin    false    261            �           2606    25223 )   actions_t actions_t_action_id_lang_id_key 
   CONSTRAINT     q   ALTER TABLE ONLY mymes.actions_t
    ADD CONSTRAINT actions_t_action_id_lang_id_key UNIQUE (action_id, lang_id);
 R   ALTER TABLE ONLY mymes.actions_t DROP CONSTRAINT actions_t_action_id_lang_id_key;
       mymes         admin    false    262    262            �           2606    25533 !   resource_timeoff ap_holidays_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY mymes.resource_timeoff
    ADD CONSTRAINT ap_holidays_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY mymes.resource_timeoff DROP CONSTRAINT ap_holidays_pkey;
       mymes         admin    false    292            �           2606    25422 "   availabilities availabilities_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY mymes.availabilities
    ADD CONSTRAINT availabilities_pkey PRIMARY KEY (id);
 K   ALTER TABLE ONLY mymes.availabilities DROP CONSTRAINT availabilities_pkey;
       mymes         cbtpost    false    224            �           2606    16959 /   availability_profiles availability_profile_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY mymes.availability_profiles
    ADD CONSTRAINT availability_profile_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY mymes.availability_profiles DROP CONSTRAINT availability_profile_pkey;
       mymes         cbtpost    false    223            �           2606    17005 @   availability_profiles_t availability_profile_t_ap_id_land_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY mymes.availability_profiles_t
    ADD CONSTRAINT availability_profile_t_ap_id_land_id_key UNIQUE (ap_id, lang_id);
 i   ALTER TABLE ONLY mymes.availability_profiles_t DROP CONSTRAINT availability_profile_t_ap_id_land_id_key;
       mymes         cbtpost    false    227    227            �           2606    25376    bom bom_pkey 
   CONSTRAINT     I   ALTER TABLE ONLY mymes.bom
    ADD CONSTRAINT bom_pkey PRIMARY KEY (id);
 5   ALTER TABLE ONLY mymes.bom DROP CONSTRAINT bom_pkey;
       mymes         admin    false    280            8           2606    27496    event_triggers checks_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY mymes.event_triggers
    ADD CONSTRAINT checks_pkey PRIMARY KEY (id);
 C   ALTER TABLE ONLY mymes.event_triggers DROP CONSTRAINT checks_pkey;
       mymes         admin    false    337            y           2606    16865 "   configurations configurations_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY mymes.configurations
    ADD CONSTRAINT configurations_pkey PRIMARY KEY (key);
 K   ALTER TABLE ONLY mymes.configurations DROP CONSTRAINT configurations_pkey;
       mymes         cbtpost    false    210                       2606    26509    convers convers_id_row_type_key 
   CONSTRAINT     a   ALTER TABLE ONLY mymes.convers
    ADD CONSTRAINT convers_id_row_type_key UNIQUE (id, row_type);
 H   ALTER TABLE ONLY mymes.convers DROP CONSTRAINT convers_id_row_type_key;
       mymes         admin    false    307    307            u           2606    17223     departments departments_name_key 
   CONSTRAINT     Z   ALTER TABLE ONLY mymes.departments
    ADD CONSTRAINT departments_name_key UNIQUE (name);
 I   ALTER TABLE ONLY mymes.departments DROP CONSTRAINT departments_name_key;
       mymes         cbtpost    false    209            w           2606    16841    departments departments_pkey 
   CONSTRAINT     Y   ALTER TABLE ONLY mymes.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);
 E   ALTER TABLE ONLY mymes.departments DROP CONSTRAINT departments_pkey;
       mymes         cbtpost    false    209            s           2606    16903 /   departments_t departments_t_dept_id_lang_id_key 
   CONSTRAINT     u   ALTER TABLE ONLY mymes.departments_t
    ADD CONSTRAINT departments_t_dept_id_lang_id_key UNIQUE (dept_id, lang_id);
 X   ALTER TABLE ONLY mymes.departments_t DROP CONSTRAINT departments_t_dept_id_lang_id_key;
       mymes         cbtpost    false    207    207            �           2606    25900    employees employees_id_key 
   CONSTRAINT     R   ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_id_key UNIQUE (id);
 C   ALTER TABLE ONLY mymes.employees DROP CONSTRAINT employees_id_key;
       mymes         cbtpost    false    219            �           2606    26298    employees employees_name_key 
   CONSTRAINT     V   ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_name_key UNIQUE (name);
 E   ALTER TABLE ONLY mymes.employees DROP CONSTRAINT employees_name_key;
       mymes         cbtpost    false    219            �           2606    26075    employees employees_pkey 
   CONSTRAINT     U   ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);
 A   ALTER TABLE ONLY mymes.employees DROP CONSTRAINT employees_pkey;
       mymes         cbtpost    false    219            �           2606    25907    equipments equipments_id_key 
   CONSTRAINT     T   ALTER TABLE ONLY mymes.equipments
    ADD CONSTRAINT equipments_id_key UNIQUE (id);
 E   ALTER TABLE ONLY mymes.equipments DROP CONSTRAINT equipments_id_key;
       mymes         cbtpost    false    220            �           2606    26296    equipments equipments_name_key 
   CONSTRAINT     X   ALTER TABLE ONLY mymes.equipments
    ADD CONSTRAINT equipments_name_key UNIQUE (name);
 G   ALTER TABLE ONLY mymes.equipments DROP CONSTRAINT equipments_name_key;
       mymes         cbtpost    false    220            �           2606    26043    equipments equipments_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY mymes.equipments
    ADD CONSTRAINT equipments_pkey PRIMARY KEY (id);
 C   ALTER TABLE ONLY mymes.equipments DROP CONSTRAINT equipments_pkey;
       mymes         cbtpost    false    220            :           2606    35677 &   event_triggers event_triggers_name_key 
   CONSTRAINT     `   ALTER TABLE ONLY mymes.event_triggers
    ADD CONSTRAINT event_triggers_name_key UNIQUE (name);
 O   ALTER TABLE ONLY mymes.event_triggers DROP CONSTRAINT event_triggers_name_key;
       mymes         admin    false    337                       2606    26860    fault fault_id_row_type_key 
   CONSTRAINT     ]   ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_id_row_type_key UNIQUE (id, row_type);
 D   ALTER TABLE ONLY mymes.fault DROP CONSTRAINT fault_id_row_type_key;
       mymes         admin    false    313    313                       2606    26841    fault fault_pkey 
   CONSTRAINT     M   ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_pkey PRIMARY KEY (id);
 9   ALTER TABLE ONLY mymes.fault DROP CONSTRAINT fault_pkey;
       mymes         admin    false    313            (           2606    27285 6   fault_type_act fault_type_act_fault_type_id_act_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY mymes.fault_type_act
    ADD CONSTRAINT fault_type_act_fault_type_id_act_id_key UNIQUE (fault_type_id, action_id);
 _   ALTER TABLE ONLY mymes.fault_type_act DROP CONSTRAINT fault_type_act_fault_type_id_act_id_key;
       mymes         admin    false    323    323            *           2606    27380 "   fault_type_act fault_type_act_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY mymes.fault_type_act
    ADD CONSTRAINT fault_type_act_pkey PRIMARY KEY (id);
 K   ALTER TABLE ONLY mymes.fault_type_act DROP CONSTRAINT fault_type_act_pkey;
       mymes         admin    false    323                       2606    27264 !   fault_type fault_type_extname_key 
   CONSTRAINT     ^   ALTER TABLE ONLY mymes.fault_type
    ADD CONSTRAINT fault_type_extname_key UNIQUE (extname);
 J   ALTER TABLE ONLY mymes.fault_type DROP CONSTRAINT fault_type_extname_key;
       mymes         admin    false    309            2           2606    27390 $   fix_act fix_act_fix_id_action_id_key 
   CONSTRAINT     k   ALTER TABLE ONLY mymes.fix_act
    ADD CONSTRAINT fix_act_fix_id_action_id_key UNIQUE (fix_id, action_id);
 M   ALTER TABLE ONLY mymes.fix_act DROP CONSTRAINT fix_act_fix_id_action_id_key;
       mymes         admin    false    330    330            4           2606    27388    fix_act fix_act_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY mymes.fix_act
    ADD CONSTRAINT fix_act_pkey PRIMARY KEY (id);
 =   ALTER TABLE ONLY mymes.fix_act DROP CONSTRAINT fix_act_pkey;
       mymes         admin    false    330            ,           2606    27351    fix fix_extname_key 
   CONSTRAINT     P   ALTER TABLE ONLY mymes.fix
    ADD CONSTRAINT fix_extname_key UNIQUE (extname);
 <   ALTER TABLE ONLY mymes.fix DROP CONSTRAINT fix_extname_key;
       mymes         admin    false    326            .           2606    27353    fix fix_name_key 
   CONSTRAINT     J   ALTER TABLE ONLY mymes.fix
    ADD CONSTRAINT fix_name_key UNIQUE (name);
 9   ALTER TABLE ONLY mymes.fix DROP CONSTRAINT fix_name_key;
       mymes         admin    false    326            0           2606    27349    fix fix_pkey 
   CONSTRAINT     I   ALTER TABLE ONLY mymes.fix
    ADD CONSTRAINT fix_pkey PRIMARY KEY (id);
 5   ALTER TABLE ONLY mymes.fix DROP CONSTRAINT fix_pkey;
       mymes         admin    false    326                       2606    26869 %   sendable identifiable_id_row_type_key 
   CONSTRAINT     g   ALTER TABLE ONLY mymes.sendable
    ADD CONSTRAINT identifiable_id_row_type_key UNIQUE (id, row_type);
 N   ALTER TABLE ONLY mymes.sendable DROP CONSTRAINT identifiable_id_row_type_key;
       mymes         admin    false    317    317                       2606    26833    sendable identifiable_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY mymes.sendable
    ADD CONSTRAINT identifiable_pkey PRIMARY KEY (id);
 C   ALTER TABLE ONLY mymes.sendable DROP CONSTRAINT identifiable_pkey;
       mymes         admin    false    317                       2606    35802 &   identifier_links identifier_links_pkey 
   CONSTRAINT     c   ALTER TABLE ONLY mymes.identifier_links
    ADD CONSTRAINT identifier_links_pkey PRIMARY KEY (id);
 O   ALTER TABLE ONLY mymes.identifier_links DROP CONSTRAINT identifier_links_pkey;
       mymes         admin    false    318            �           2606    26999 (   identifier identifier_name_parent_id_key 
   CONSTRAINT     m   ALTER TABLE ONLY mymes.identifier
    ADD CONSTRAINT identifier_name_parent_id_key UNIQUE (name, parent_id);
 Q   ALTER TABLE ONLY mymes.identifier DROP CONSTRAINT identifier_name_parent_id_key;
       mymes         admin    false    288    288            �           2606    25486    identifier identifiers_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY mymes.identifier
    ADD CONSTRAINT identifiers_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY mymes.identifier DROP CONSTRAINT identifiers_pkey;
       mymes         admin    false    288            �           2606    25253 >   import_schamas_t import_schamas_t_import_schama_id_lang_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY mymes.import_schamas_t
    ADD CONSTRAINT import_schamas_t_import_schama_id_lang_id_key UNIQUE (import_schama_id, lang_id);
 g   ALTER TABLE ONLY mymes.import_schamas_t DROP CONSTRAINT import_schamas_t_import_schama_id_lang_id_key;
       mymes         admin    false    266    266            �           2606    25245 "   import_schemas import_schemas_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY mymes.import_schemas
    ADD CONSTRAINT import_schemas_pkey PRIMARY KEY (id);
 K   ALTER TABLE ONLY mymes.import_schemas DROP CONSTRAINT import_schemas_pkey;
       mymes         admin    false    265            �           2606    26743    kit kit_pkey 
   CONSTRAINT     I   ALTER TABLE ONLY mymes.kit
    ADD CONSTRAINT kit_pkey PRIMARY KEY (id);
 5   ALTER TABLE ONLY mymes.kit DROP CONSTRAINT kit_pkey;
       mymes         admin    false    263            �           2606    25234    kit kit_serial_partname_lot_key 
   CONSTRAINT     m   ALTER TABLE ONLY mymes.kit
    ADD CONSTRAINT kit_serial_partname_lot_key UNIQUE (serial_id, partname, lot);
 H   ALTER TABLE ONLY mymes.kit DROP CONSTRAINT kit_serial_partname_lot_key;
       mymes         admin    false    263    263    263            6           2606    27453    kit_usage kit_usage_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY mymes.kit_usage
    ADD CONSTRAINT kit_usage_pkey PRIMARY KEY (start_date, kit_id);
 A   ALTER TABLE ONLY mymes.kit_usage DROP CONSTRAINT kit_usage_pkey;
       mymes         admin    false    333    333            �           2606    25420 $   local_actions local_actions_name_key 
   CONSTRAINT     ^   ALTER TABLE ONLY mymes.local_actions
    ADD CONSTRAINT local_actions_name_key UNIQUE (name);
 M   ALTER TABLE ONLY mymes.local_actions DROP CONSTRAINT local_actions_name_key;
       mymes         admin    false    283            �           2606    25418     local_actions local_actions_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY mymes.local_actions
    ADD CONSTRAINT local_actions_pkey PRIMARY KEY (id);
 I   ALTER TABLE ONLY mymes.local_actions DROP CONSTRAINT local_actions_pkey;
       mymes         admin    false    283            �           2606    25438 $   local_actions_t local_actions_t_pkey 
   CONSTRAINT     w   ALTER TABLE ONLY mymes.local_actions_t
    ADD CONSTRAINT local_actions_t_pkey PRIMARY KEY (local_action_id, lang_id);
 M   ALTER TABLE ONLY mymes.local_actions_t DROP CONSTRAINT local_actions_t_pkey;
       mymes         admin    false    284    284            �           2606    26733    locations locations_pkey 
   CONSTRAINT     U   ALTER TABLE ONLY mymes.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);
 A   ALTER TABLE ONLY mymes.locations DROP CONSTRAINT locations_pkey;
       mymes         admin    false    259                       2606    26552 !   fault_status malf_status_name_key 
   CONSTRAINT     [   ALTER TABLE ONLY mymes.fault_status
    ADD CONSTRAINT malf_status_name_key UNIQUE (name);
 J   ALTER TABLE ONLY mymes.fault_status DROP CONSTRAINT malf_status_name_key;
       mymes         admin    false    311                       2606    26550    fault_status malf_status_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY mymes.fault_status
    ADD CONSTRAINT malf_status_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY mymes.fault_status DROP CONSTRAINT malf_status_pkey;
       mymes         admin    false    311                       2606    26526    fault_type malf_type_name_key 
   CONSTRAINT     W   ALTER TABLE ONLY mymes.fault_type
    ADD CONSTRAINT malf_type_name_key UNIQUE (name);
 F   ALTER TABLE ONLY mymes.fault_type DROP CONSTRAINT malf_type_name_key;
       mymes         admin    false    309                       2606    26554    fault_type malf_type_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY mymes.fault_type
    ADD CONSTRAINT malf_type_pkey PRIMARY KEY (id);
 B   ALTER TABLE ONLY mymes.fault_type DROP CONSTRAINT malf_type_pkey;
       mymes         admin    false    309            �           2606    17115 (   malfunction_types malfunction_types_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY mymes.malfunction_types
    ADD CONSTRAINT malfunction_types_pkey PRIMARY KEY (id);
 Q   ALTER TABLE ONLY mymes.malfunction_types DROP CONSTRAINT malfunction_types_pkey;
       mymes         cbtpost    false    237            �           2606    17085    malfunctions malfunctions_pkey 
   CONSTRAINT     [   ALTER TABLE ONLY mymes.malfunctions
    ADD CONSTRAINT malfunctions_pkey PRIMARY KEY (id);
 G   ALTER TABLE ONLY mymes.malfunctions DROP CONSTRAINT malfunctions_pkey;
       mymes         cbtpost    false    235            �           2606    17120 8   malfunctions_t malfunctions_t_malfunction_id_lang_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY mymes.malfunctions_t
    ADD CONSTRAINT malfunctions_t_malfunction_id_lang_id_key UNIQUE (malfunction_id, lang_id);
 a   ALTER TABLE ONLY mymes.malfunctions_t DROP CONSTRAINT malfunctions_t_malfunction_id_lang_id_key;
       mymes         cbtpost    false    238    238            �           2606    17203 "   mnt_plan_items mnt_plan_items_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY mymes.mnt_plan_items
    ADD CONSTRAINT mnt_plan_items_pkey PRIMARY KEY (id);
 K   ALTER TABLE ONLY mymes.mnt_plan_items DROP CONSTRAINT mnt_plan_items_pkey;
       mymes         cbtpost    false    249            �           2606    17186    mnt_plans mnt_plan_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY mymes.mnt_plans
    ADD CONSTRAINT mnt_plan_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY mymes.mnt_plans DROP CONSTRAINT mnt_plan_pkey;
       mymes         cbtpost    false    248            �           2606    25590     notifications notifications_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY mymes.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);
 I   ALTER TABLE ONLY mymes.notifications DROP CONSTRAINT notifications_pkey;
       mymes         admin    false    295            "           2606    27043    numerators numerators_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY mymes.numerators
    ADD CONSTRAINT numerators_pkey PRIMARY KEY (id);
 C   ALTER TABLE ONLY mymes.numerators DROP CONSTRAINT numerators_pkey;
       mymes         admin    false    319            $           2606    27051     numerators numerators_prefix_key 
   CONSTRAINT     \   ALTER TABLE ONLY mymes.numerators
    ADD CONSTRAINT numerators_prefix_key UNIQUE (prefix);
 I   ALTER TABLE ONLY mymes.numerators DROP CONSTRAINT numerators_prefix_key;
       mymes         admin    false    319            &           2606    27049 "   numerators numerators_row_type_key 
   CONSTRAINT     `   ALTER TABLE ONLY mymes.numerators
    ADD CONSTRAINT numerators_row_type_key UNIQUE (row_type);
 K   ALTER TABLE ONLY mymes.numerators DROP CONSTRAINT numerators_row_type_key;
       mymes         admin    false    319            {           2606    26114    part part_id_key 
   CONSTRAINT     H   ALTER TABLE ONLY mymes.part
    ADD CONSTRAINT part_id_key UNIQUE (id);
 9   ALTER TABLE ONLY mymes.part DROP CONSTRAINT part_id_key;
       mymes         cbtpost    false    212            }           2606    26442    part part_name_revision_key 
   CONSTRAINT     _   ALTER TABLE ONLY mymes.part
    ADD CONSTRAINT part_name_revision_key UNIQUE (name, revision);
 D   ALTER TABLE ONLY mymes.part DROP CONSTRAINT part_name_revision_key;
       mymes         cbtpost    false    212    212                       2606    16873    part part_pkey 
   CONSTRAINT     K   ALTER TABLE ONLY mymes.part
    ADD CONSTRAINT part_pkey PRIMARY KEY (id);
 7   ALTER TABLE ONLY mymes.part DROP CONSTRAINT part_pkey;
       mymes         cbtpost    false    212            �           2606    16893    part_status part_status_pkey 
   CONSTRAINT     Y   ALTER TABLE ONLY mymes.part_status
    ADD CONSTRAINT part_status_pkey PRIMARY KEY (id);
 E   ALTER TABLE ONLY mymes.part_status DROP CONSTRAINT part_status_pkey;
       mymes         cbtpost    false    215            �           2606    16901 6   part_status_t part_status_t_part_status_id_lang_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY mymes.part_status_t
    ADD CONSTRAINT part_status_t_part_status_id_lang_id_key UNIQUE (part_status_id, lang_id);
 _   ALTER TABLE ONLY mymes.part_status_t DROP CONSTRAINT part_status_t_part_status_id_lang_id_key;
       mymes         cbtpost    false    216    216                       2606    26359    positions positions_pkey 
   CONSTRAINT     U   ALTER TABLE ONLY mymes.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);
 A   ALTER TABLE ONLY mymes.positions DROP CONSTRAINT positions_pkey;
       mymes         admin    false    301                       2606    26367 /   positions_t positions_t_position_id_lang_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY mymes.positions_t
    ADD CONSTRAINT positions_t_position_id_lang_id_key UNIQUE (position_id, lang_id);
 X   ALTER TABLE ONLY mymes.positions_t DROP CONSTRAINT positions_t_position_id_lang_id_key;
       mymes         admin    false    302    302            �           2606    26205     preferences preferences_name_key 
   CONSTRAINT     Z   ALTER TABLE ONLY mymes.preferences
    ADD CONSTRAINT preferences_name_key UNIQUE (name);
 I   ALTER TABLE ONLY mymes.preferences DROP CONSTRAINT preferences_name_key;
       mymes         admin    false    290            �           2606    25332    proc_act proc_act_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_pkey PRIMARY KEY (id);
 ?   ALTER TABLE ONLY mymes.proc_act DROP CONSTRAINT proc_act_pkey;
       mymes         admin    false    276            �           2606    25334 '   proc_act proc_act_process_id_act_id_key 
   CONSTRAINT     o   ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_process_id_act_id_key UNIQUE (process_id, act_id);
 P   ALTER TABLE ONLY mymes.proc_act DROP CONSTRAINT proc_act_process_id_act_id_key;
       mymes         admin    false    276    276            �           2606    25336 $   proc_act proc_act_process_id_pos_key 
   CONSTRAINT     i   ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_process_id_pos_key UNIQUE (process_id, pos);
 M   ALTER TABLE ONLY mymes.proc_act DROP CONSTRAINT proc_act_process_id_pos_key;
       mymes         admin    false    276    276            �           2606    26444    process process_erpproc_key 
   CONSTRAINT     X   ALTER TABLE ONLY mymes.process
    ADD CONSTRAINT process_erpproc_key UNIQUE (erpproc);
 D   ALTER TABLE ONLY mymes.process DROP CONSTRAINT process_erpproc_key;
       mymes         admin    false    273            �           2606    25314    process process_name_key 
   CONSTRAINT     R   ALTER TABLE ONLY mymes.process
    ADD CONSTRAINT process_name_key UNIQUE (name);
 A   ALTER TABLE ONLY mymes.process DROP CONSTRAINT process_name_key;
       mymes         admin    false    273            �           2606    25312    process process_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY mymes.process
    ADD CONSTRAINT process_pkey PRIMARY KEY (id);
 =   ALTER TABLE ONLY mymes.process DROP CONSTRAINT process_pkey;
       mymes         admin    false    273            �           2606    17169    repair_types repair_types_pkey 
   CONSTRAINT     [   ALTER TABLE ONLY mymes.repair_types
    ADD CONSTRAINT repair_types_pkey PRIMARY KEY (id);
 G   ALTER TABLE ONLY mymes.repair_types DROP CONSTRAINT repair_types_pkey;
       mymes         cbtpost    false    245            �           2606    17158    repairs repairs_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY mymes.repairs
    ADD CONSTRAINT repairs_pkey PRIMARY KEY (id);
 =   ALTER TABLE ONLY mymes.repairs DROP CONSTRAINT repairs_pkey;
       mymes         cbtpost    false    243            �           2606    26345    resource_arc resource_arc_pkey 
   CONSTRAINT     [   ALTER TABLE ONLY mymes.resource_arc
    ADD CONSTRAINT resource_arc_pkey PRIMARY KEY (id);
 G   ALTER TABLE ONLY mymes.resource_arc DROP CONSTRAINT resource_arc_pkey;
       mymes         admin    false    298                       2606    26347 .   resource_arc resource_arc_son_id_parent_id_key 
   CONSTRAINT     u   ALTER TABLE ONLY mymes.resource_arc
    ADD CONSTRAINT resource_arc_son_id_parent_id_key UNIQUE (son_id, parent_id);
 W   ALTER TABLE ONLY mymes.resource_arc DROP CONSTRAINT resource_arc_son_id_parent_id_key;
       mymes         admin    false    298    298            �           2606    25969 &   resource_groups resource_groups_id_key 
   CONSTRAINT     ^   ALTER TABLE ONLY mymes.resource_groups
    ADD CONSTRAINT resource_groups_id_key UNIQUE (id);
 O   ALTER TABLE ONLY mymes.resource_groups DROP CONSTRAINT resource_groups_id_key;
       mymes         cbtpost    false    221            �           2606    26300 (   resource_groups resource_groups_name_key 
   CONSTRAINT     b   ALTER TABLE ONLY mymes.resource_groups
    ADD CONSTRAINT resource_groups_name_key UNIQUE (name);
 Q   ALTER TABLE ONLY mymes.resource_groups DROP CONSTRAINT resource_groups_name_key;
       mymes         cbtpost    false    221            �           2606    26077 $   resource_groups resource_groups_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY mymes.resource_groups
    ADD CONSTRAINT resource_groups_pkey PRIMARY KEY (id);
 M   ALTER TABLE ONLY mymes.resource_groups DROP CONSTRAINT resource_groups_pkey;
       mymes         cbtpost    false    221            �           2606    25898    resources resources_id_key 
   CONSTRAINT     R   ALTER TABLE ONLY mymes.resources
    ADD CONSTRAINT resources_id_key UNIQUE (id);
 C   ALTER TABLE ONLY mymes.resources DROP CONSTRAINT resources_id_key;
       mymes         cbtpost    false    218            �           2606    26294    resources resources_name_key 
   CONSTRAINT     V   ALTER TABLE ONLY mymes.resources
    ADD CONSTRAINT resources_name_key UNIQUE (name);
 E   ALTER TABLE ONLY mymes.resources DROP CONSTRAINT resources_name_key;
       mymes         cbtpost    false    218            �           2606    16925    resources resources_pkey 
   CONSTRAINT     U   ALTER TABLE ONLY mymes.resources
    ADD CONSTRAINT resources_pkey PRIMARY KEY (id);
 A   ALTER TABLE ONLY mymes.resources DROP CONSTRAINT resources_pkey;
       mymes         cbtpost    false    218            �           2606    25348    serial_act serial_act_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY mymes.serial_act
    ADD CONSTRAINT serial_act_pkey PRIMARY KEY (id);
 C   ALTER TABLE ONLY mymes.serial_act DROP CONSTRAINT serial_act_pkey;
       mymes         admin    false    278            �           2606    25350 *   serial_act serial_act_serial_id_act_id_key 
   CONSTRAINT     q   ALTER TABLE ONLY mymes.serial_act
    ADD CONSTRAINT serial_act_serial_id_act_id_key UNIQUE (serial_id, act_id);
 S   ALTER TABLE ONLY mymes.serial_act DROP CONSTRAINT serial_act_serial_id_act_id_key;
       mymes         admin    false    278    278            �           2606    25352 '   serial_act serial_act_serial_id_pos_key 
   CONSTRAINT     k   ALTER TABLE ONLY mymes.serial_act
    ADD CONSTRAINT serial_act_serial_id_pos_key UNIQUE (serial_id, pos);
 P   ALTER TABLE ONLY mymes.serial_act DROP CONSTRAINT serial_act_serial_id_pos_key;
       mymes         admin    false    278    278            �           2606    25981 $   serial_statuses serial_statuses_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY mymes.serial_statuses
    ADD CONSTRAINT serial_statuses_pkey PRIMARY KEY (id);
 M   ALTER TABLE ONLY mymes.serial_statuses DROP CONSTRAINT serial_statuses_pkey;
       mymes         admin    false    268            �           2606    25270 9   serial_statuses_t serial_statuses_t_serial_id_lang_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY mymes.serial_statuses_t
    ADD CONSTRAINT serial_statuses_t_serial_id_lang_id_key UNIQUE (serial_status_id, lang_id);
 b   ALTER TABLE ONLY mymes.serial_statuses_t DROP CONSTRAINT serial_statuses_t_serial_id_lang_id_key;
       mymes         admin    false    269    269            �           2606    25602    serials serials_id_key 
   CONSTRAINT     N   ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_id_key UNIQUE (id);
 ?   ALTER TABLE ONLY mymes.serials DROP CONSTRAINT serials_id_key;
       mymes         admin    false    258            �           2606    26435    serials serials_name_key 
   CONSTRAINT     R   ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_name_key UNIQUE (name);
 A   ALTER TABLE ONLY mymes.serials DROP CONSTRAINT serials_name_key;
       mymes         admin    false    258            �           2606    25600    serials serials_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_pkey PRIMARY KEY (id);
 =   ALTER TABLE ONLY mymes.serials DROP CONSTRAINT serials_pkey;
       mymes         admin    false    258            �           2606    25278 )   serials_t serials_t_serial_id_lang_id_key 
   CONSTRAINT     q   ALTER TABLE ONLY mymes.serials_t
    ADD CONSTRAINT serials_t_serial_id_lang_id_key UNIQUE (serial_id, lang_id);
 R   ALTER TABLE ONLY mymes.serials_t DROP CONSTRAINT serials_t_serial_id_lang_id_key;
       mymes         admin    false    270    270            �           2606    17034    standards standards_pkey 
   CONSTRAINT     U   ALTER TABLE ONLY mymes.standards
    ADD CONSTRAINT standards_pkey PRIMARY KEY (id);
 A   ALTER TABLE ONLY mymes.standards DROP CONSTRAINT standards_pkey;
       mymes         cbtpost    false    230            �           2606    17045 $   standards_types standards_types_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY mymes.standards_types
    ADD CONSTRAINT standards_types_pkey PRIMARY KEY (id);
 M   ALTER TABLE ONLY mymes.standards_types DROP CONSTRAINT standards_types_pkey;
       mymes         cbtpost    false    232            >           2606    27546    tables tables_name_key 
   CONSTRAINT     P   ALTER TABLE ONLY mymes.tables
    ADD CONSTRAINT tables_name_key UNIQUE (name);
 ?   ALTER TABLE ONLY mymes.tables DROP CONSTRAINT tables_name_key;
       mymes         admin    false    340            @           2606    27544    tables tables_pkey 
   CONSTRAINT     O   ALTER TABLE ONLY mymes.tables
    ADD CONSTRAINT tables_pkey PRIMARY KEY (id);
 ;   ALTER TABLE ONLY mymes.tables DROP CONSTRAINT tables_pkey;
       mymes         admin    false    340            �           2606    26867 '   work_report work_report_id_row_type_key 
   CONSTRAINT     i   ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_id_row_type_key UNIQUE (id, row_type);
 P   ALTER TABLE ONLY mymes.work_report DROP CONSTRAINT work_report_id_row_type_key;
       mymes         admin    false    286    286            �           2606    26825    work_report work_report_pkey 
   CONSTRAINT     Y   ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_pkey PRIMARY KEY (id);
 E   ALTER TABLE ONLY mymes.work_report DROP CONSTRAINT work_report_pkey;
       mymes         admin    false    286            k           2606    16770    users USERS_USERNAME_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.users
    ADD CONSTRAINT "USERS_USERNAME_key" UNIQUE (username);
 D   ALTER TABLE ONLY public.users DROP CONSTRAINT "USERS_USERNAME_key";
       public         cbtpost    false    200            m           2606    16772    users USERS_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.users
    ADD CONSTRAINT "USERS_pkey" PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.users DROP CONSTRAINT "USERS_pkey";
       public         cbtpost    false    200            �           2606    17237    bugs bugs_pkey 
   CONSTRAINT     L   ALTER TABLE ONLY public.bugs
    ADD CONSTRAINT bugs_pkey PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.bugs DROP CONSTRAINT bugs_pkey;
       public         cbtpost    false    254            <           2606    27530 "   condition_type condition_type_pkey 
   CONSTRAINT     g   ALTER TABLE ONLY public.condition_type
    ADD CONSTRAINT condition_type_pkey PRIMARY KEY (condition);
 L   ALTER TABLE ONLY public.condition_type DROP CONSTRAINT condition_type_pkey;
       public         admin    false    338            �           1259    27275    BOM_part_id_partname    INDEX     T   CREATE INDEX "BOM_part_id_partname" ON mymes.bom USING btree (parent_id, partname);
 )   DROP INDEX mymes."BOM_part_id_partname";
       mymes         admin    false    280    280            �           1259    27274    LOCATIONS_part_id_partname    INDEX     ^   CREATE INDEX "LOCATIONS_part_id_partname" ON mymes.locations USING btree (part_id, partname);
 /   DROP INDEX mymes."LOCATIONS_part_id_partname";
       mymes         admin    false    259    259                        1259    27310    unique_index_identifier_links    INDEX     �   CREATE UNIQUE INDEX unique_index_identifier_links ON mymes.identifier_links USING btree (identifier_id, serial_id, act_id) WHERE (row_type = 'work_report'::public.row_type);
 0   DROP INDEX mymes.unique_index_identifier_links;
       mymes         admin    false    956    318    318    318    318            i           1259    16773    USERNAME    INDEX     G   CREATE UNIQUE INDEX "USERNAME" ON public.users USING btree (username);
    DROP INDEX public."USERNAME";
       public         cbtpost    false    200            J           2618    27062 !   numerators numerators_del_protect    RULE     \   CREATE RULE numerators_del_protect AS
    ON DELETE TO mymes.numerators DO INSTEAD NOTHING;
 6   DROP RULE numerators_del_protect ON mymes.numerators;
       mymes       admin    false    319    319    319            K           2618    27063 #   preferences preferences_del_protect    RULE     ^   CREATE RULE preferences_del_protect AS
    ON DELETE TO mymes.preferences DO INSTEAD NOTHING;
 8   DROP RULE preferences_del_protect ON mymes.preferences;
       mymes       admin    false    290    290    290            �           2620    35812 6   identifier_links event_trigger_insert_identifier_links    TRIGGER     �   CREATE TRIGGER event_trigger_insert_identifier_links BEFORE INSERT ON mymes.identifier_links FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert_identifier_links();
 N   DROP TRIGGER event_trigger_insert_identifier_links ON mymes.identifier_links;
       mymes       admin    false    395    318            �           2620    35700    process events_trigger    TRIGGER     z   CREATE TRIGGER events_trigger AFTER UPDATE ON mymes.process FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 .   DROP TRIGGER events_trigger ON mymes.process;
       mymes       admin    false    273    396            �           2620    35714    actions events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.actions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 5   DROP TRIGGER events_trigger_delete ON mymes.actions;
       mymes       admin    false    394    261            �           2620    35715    serials events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.serials FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 5   DROP TRIGGER events_trigger_delete ON mymes.serials;
       mymes       admin    false    394    258            �           2620    35718    bom events_trigger_delete    TRIGGER     ~   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.bom FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 1   DROP TRIGGER events_trigger_delete ON mymes.bom;
       mymes       admin    false    280    394            �           2620    35721    kit events_trigger_delete    TRIGGER     ~   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.kit FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 1   DROP TRIGGER events_trigger_delete ON mymes.kit;
       mymes       admin    false    394    263            �           2620    35724 +   availability_profiles events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.availability_profiles FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 C   DROP TRIGGER events_trigger_delete ON mymes.availability_profiles;
       mymes       cbtpost    false    394    223            �           2620    35727    employees events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.employees FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 7   DROP TRIGGER events_trigger_delete ON mymes.employees;
       mymes       cbtpost    false    394    219            �           2620    35730     equipments events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.equipments FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 8   DROP TRIGGER events_trigger_delete ON mymes.equipments;
       mymes       cbtpost    false    220    394            �           2620    35733    fault events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();

ALTER TABLE mymes.fault DISABLE TRIGGER events_trigger_delete;
 3   DROP TRIGGER events_trigger_delete ON mymes.fault;
       mymes       admin    false    394    313            ~           2620    35736    part events_trigger_delete    TRIGGER        CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 2   DROP TRIGGER events_trigger_delete ON mymes.part;
       mymes       cbtpost    false    394    212            �           2620    35739 !   work_report events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();

ALTER TABLE mymes.work_report DISABLE TRIGGER events_trigger_delete;
 9   DROP TRIGGER events_trigger_delete ON mymes.work_report;
       mymes       admin    false    286    394            �           2620    35742     identifier events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 8   DROP TRIGGER events_trigger_delete ON mymes.identifier;
       mymes       admin    false    394    288            �           2620    35745    locations events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.locations FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 7   DROP TRIGGER events_trigger_delete ON mymes.locations;
       mymes       admin    false    394    259            �           2620    35748 "   malfunctions events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.malfunctions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 :   DROP TRIGGER events_trigger_delete ON mymes.malfunctions;
       mymes       cbtpost    false    235    394            �           2620    35751    mnt_plans events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.mnt_plans FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 7   DROP TRIGGER events_trigger_delete ON mymes.mnt_plans;
       mymes       cbtpost    false    394    248            �           2620    35754    positions events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.positions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 7   DROP TRIGGER events_trigger_delete ON mymes.positions;
       mymes       admin    false    301    394            �           2620    35757    repairs events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.repairs FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 5   DROP TRIGGER events_trigger_delete ON mymes.repairs;
       mymes       cbtpost    false    394    243            �           2620    35760    resources events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.resources FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 7   DROP TRIGGER events_trigger_delete ON mymes.resources;
       mymes       cbtpost    false    218    394            �           2620    35770 &   identifier_links events_trigger_delete    TRIGGER     �   CREATE TRIGGER events_trigger_delete BEFORE DELETE ON mymes.identifier_links FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_delete();
 >   DROP TRIGGER events_trigger_delete ON mymes.identifier_links;
       mymes       admin    false    394    318            �           2620    35713    actions events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.actions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 5   DROP TRIGGER events_trigger_insert ON mymes.actions;
       mymes       admin    false    392    261            �           2620    35716    serials events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.serials FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 5   DROP TRIGGER events_trigger_insert ON mymes.serials;
       mymes       admin    false    392    258            �           2620    35719    bom events_trigger_insert    TRIGGER     ~   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.bom FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 1   DROP TRIGGER events_trigger_insert ON mymes.bom;
       mymes       admin    false    280    392            �           2620    35722    kit events_trigger_insert    TRIGGER     ~   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.kit FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 1   DROP TRIGGER events_trigger_insert ON mymes.kit;
       mymes       admin    false    392    263            �           2620    35725 +   availability_profiles events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.availability_profiles FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 C   DROP TRIGGER events_trigger_insert ON mymes.availability_profiles;
       mymes       cbtpost    false    223    392            �           2620    35728    employees events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.employees FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 7   DROP TRIGGER events_trigger_insert ON mymes.employees;
       mymes       cbtpost    false    219    392            �           2620    35731     equipments events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.equipments FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 8   DROP TRIGGER events_trigger_insert ON mymes.equipments;
       mymes       cbtpost    false    220    392            �           2620    35734    fault events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 3   DROP TRIGGER events_trigger_insert ON mymes.fault;
       mymes       admin    false    392    313                       2620    35737    part events_trigger_insert    TRIGGER        CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 2   DROP TRIGGER events_trigger_insert ON mymes.part;
       mymes       cbtpost    false    212    392            �           2620    35740 !   work_report events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 9   DROP TRIGGER events_trigger_insert ON mymes.work_report;
       mymes       admin    false    286    392            �           2620    35743     identifier events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 8   DROP TRIGGER events_trigger_insert ON mymes.identifier;
       mymes       admin    false    288    392            �           2620    35746    locations events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.locations FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 7   DROP TRIGGER events_trigger_insert ON mymes.locations;
       mymes       admin    false    259    392            �           2620    35749 "   malfunctions events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.malfunctions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 :   DROP TRIGGER events_trigger_insert ON mymes.malfunctions;
       mymes       cbtpost    false    235    392            �           2620    35752    mnt_plans events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.mnt_plans FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 7   DROP TRIGGER events_trigger_insert ON mymes.mnt_plans;
       mymes       cbtpost    false    392    248            �           2620    35755    positions events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.positions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 7   DROP TRIGGER events_trigger_insert ON mymes.positions;
       mymes       admin    false    392    301            �           2620    35758    repairs events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.repairs FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 5   DROP TRIGGER events_trigger_insert ON mymes.repairs;
       mymes       cbtpost    false    392    243            �           2620    35761    resources events_trigger_insert    TRIGGER     �   CREATE TRIGGER events_trigger_insert BEFORE INSERT ON mymes.resources FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_insert();
 7   DROP TRIGGER events_trigger_insert ON mymes.resources;
       mymes       cbtpost    false    392    218            �           2620    35712    actions events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.actions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 5   DROP TRIGGER events_trigger_update ON mymes.actions;
       mymes       admin    false    396    261            �           2620    35717    serials events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.serials FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 5   DROP TRIGGER events_trigger_update ON mymes.serials;
       mymes       admin    false    258    396            �           2620    35720    bom events_trigger_update    TRIGGER     ~   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.bom FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 1   DROP TRIGGER events_trigger_update ON mymes.bom;
       mymes       admin    false    280    396            �           2620    35723    kit events_trigger_update    TRIGGER     ~   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.kit FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 1   DROP TRIGGER events_trigger_update ON mymes.kit;
       mymes       admin    false    263    396            �           2620    35726 +   availability_profiles events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.availability_profiles FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 C   DROP TRIGGER events_trigger_update ON mymes.availability_profiles;
       mymes       cbtpost    false    396    223            �           2620    35729    employees events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.employees FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 7   DROP TRIGGER events_trigger_update ON mymes.employees;
       mymes       cbtpost    false    219    396            �           2620    35732     equipments events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.equipments FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 8   DROP TRIGGER events_trigger_update ON mymes.equipments;
       mymes       cbtpost    false    220    396            �           2620    35735    fault events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 3   DROP TRIGGER events_trigger_update ON mymes.fault;
       mymes       admin    false    396    313            �           2620    35738    part events_trigger_update    TRIGGER        CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 2   DROP TRIGGER events_trigger_update ON mymes.part;
       mymes       cbtpost    false    212    396            �           2620    35741 !   work_report events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 9   DROP TRIGGER events_trigger_update ON mymes.work_report;
       mymes       admin    false    286    396            �           2620    35744     identifier events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 8   DROP TRIGGER events_trigger_update ON mymes.identifier;
       mymes       admin    false    396    288            �           2620    35747    locations events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.locations FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 7   DROP TRIGGER events_trigger_update ON mymes.locations;
       mymes       admin    false    396    259            �           2620    35750 "   malfunctions events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.malfunctions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 :   DROP TRIGGER events_trigger_update ON mymes.malfunctions;
       mymes       cbtpost    false    396    235            �           2620    35753    mnt_plans events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.mnt_plans FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 7   DROP TRIGGER events_trigger_update ON mymes.mnt_plans;
       mymes       cbtpost    false    396    248            �           2620    35756    positions events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.positions FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 7   DROP TRIGGER events_trigger_update ON mymes.positions;
       mymes       admin    false    396    301            �           2620    35759    repairs events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.repairs FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 5   DROP TRIGGER events_trigger_update ON mymes.repairs;
       mymes       cbtpost    false    396    243            �           2620    35762    resources events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.resources FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 7   DROP TRIGGER events_trigger_update ON mymes.resources;
       mymes       cbtpost    false    218    396            �           2620    35772 &   identifier_links events_trigger_update    TRIGGER     �   CREATE TRIGGER events_trigger_update BEFORE UPDATE ON mymes.identifier_links FOR EACH ROW EXECUTE PROCEDURE public.event_trigger_update();
 >   DROP TRIGGER events_trigger_update ON mymes.identifier_links;
       mymes       admin    false    396    318            �           2620    26974    fault notify_fault    TRIGGER     n   CREATE TRIGGER notify_fault AFTER INSERT ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.fault_notify();
 *   DROP TRIGGER notify_fault ON mymes.fault;
       mymes       admin    false    380    313            �           2620    27403    identifier post_delete    TRIGGER     |   CREATE TRIGGER post_delete AFTER DELETE ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.post_delete_identifier();
 .   DROP TRIGGER post_delete ON mymes.identifier;
       mymes       admin    false    288    370            �           2620    27433    identifier_links post_insert    TRIGGER     �   CREATE TRIGGER post_insert AFTER INSERT ON mymes.identifier_links FOR EACH ROW EXECUTE PROCEDURE public.post_insert_identifier_link();
 4   DROP TRIGGER post_insert ON mymes.identifier_links;
       mymes       admin    false    391    318            �           2620    26486     notifications post_insert_notify    TRIGGER     �   CREATE TRIGGER post_insert_notify AFTER INSERT ON mymes.notifications FOR EACH ROW EXECUTE PROCEDURE public.mes_notify('notifications');
 8   DROP TRIGGER post_insert_notify ON mymes.notifications;
       mymes       admin    false    363    295            �           2620    26906    fault pre_delete_Identifiable    TRIGGER     �   CREATE TRIGGER "pre_delete_Identifiable" BEFORE DELETE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_sendable();
 7   DROP TRIGGER "pre_delete_Identifiable" ON mymes.fault;
       mymes       admin    false    360    313            �           2620    27482    work_report pre_delete_approved    TRIGGER     �   CREATE TRIGGER pre_delete_approved BEFORE DELETE ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_approved();
 7   DROP TRIGGER pre_delete_approved ON mymes.work_report;
       mymes       admin    false    386    286            �           2620    27483    fault pre_delete_approved    TRIGGER     }   CREATE TRIGGER pre_delete_approved BEFORE DELETE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_approved();
 1   DROP TRIGGER pre_delete_approved ON mymes.fault;
       mymes       admin    false    313    386            �           2620    27485 $   identifier_links pre_delete_approved    TRIGGER     �   CREATE TRIGGER pre_delete_approved BEFORE DELETE ON mymes.identifier_links FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_approved();
 <   DROP TRIGGER pre_delete_approved ON mymes.identifier_links;
       mymes       admin    false    318    386            �           2620    26904     sendable pre_delete_identifiable    TRIGGER     �   CREATE TRIGGER pre_delete_identifiable BEFORE DELETE ON mymes.sendable FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_sendable();
 8   DROP TRIGGER pre_delete_identifiable ON mymes.sendable;
       mymes       admin    false    360    317            �           2620    26911     identifier pre_delete_identifier    TRIGGER     �   CREATE TRIGGER pre_delete_identifier BEFORE DELETE ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_identifier();
 8   DROP TRIGGER pre_delete_identifier ON mymes.identifier;
       mymes       admin    false    288    364            �           2620    26905    work_report pre_delete_sendable    TRIGGER     �   CREATE TRIGGER pre_delete_sendable BEFORE DELETE ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.pre_delete_sendable();
 7   DROP TRIGGER pre_delete_sendable ON mymes.work_report;
       mymes       admin    false    360    286            �           2620    27006 %   work_report pre_insert_balance_checks    TRIGGER     �   CREATE TRIGGER pre_insert_balance_checks BEFORE INSERT ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.check_serial_act();
 =   DROP TRIGGER pre_insert_balance_checks ON mymes.work_report;
       mymes       admin    false    389    286            �           2620    26964 !   identifier pre_insert_set_part_id    TRIGGER     �   CREATE TRIGGER pre_insert_set_part_id BEFORE INSERT ON mymes.identifier FOR EACH ROW EXECUTE PROCEDURE public.pre_insert_identifier();
 9   DROP TRIGGER pre_insert_set_part_id ON mymes.identifier;
       mymes       admin    false    376    288            �           2620    27309    fault set_fault_status    TRIGGER     �   CREATE TRIGGER set_fault_status BEFORE INSERT OR UPDATE ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.set_fault_status();
 .   DROP TRIGGER set_fault_status ON mymes.fault;
       mymes       admin    false    366    313            �           2620    26944    fault set_name    TRIGGER     g   CREATE TRIGGER set_name BEFORE INSERT ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.set_name();
 &   DROP TRIGGER set_name ON mymes.fault;
       mymes       admin    false    373    313            �           2620    27052    serials set_name    TRIGGER     i   CREATE TRIGGER set_name BEFORE INSERT ON mymes.serials FOR EACH ROW EXECUTE PROCEDURE public.set_name();
 (   DROP TRIGGER set_name ON mymes.serials;
       mymes       admin    false    373    258            }           2620    27053    part set_name    TRIGGER     f   CREATE TRIGGER set_name BEFORE INSERT ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.set_name();
 %   DROP TRIGGER set_name ON mymes.part;
       mymes       cbtpost    false    373    212            �           2620    27054    actions set_name    TRIGGER     i   CREATE TRIGGER set_name BEFORE INSERT ON mymes.actions FOR EACH ROW EXECUTE PROCEDURE public.set_name();
 (   DROP TRIGGER set_name ON mymes.actions;
       mymes       admin    false    373    261            �           2620    27057    equipments set_name    TRIGGER     l   CREATE TRIGGER set_name BEFORE INSERT ON mymes.equipments FOR EACH ROW EXECUTE PROCEDURE public.set_name();
 +   DROP TRIGGER set_name ON mymes.equipments;
       mymes       cbtpost    false    373    220            �           2620    27058    malfunctions set_name    TRIGGER     n   CREATE TRIGGER set_name BEFORE INSERT ON mymes.malfunctions FOR EACH ROW EXECUTE PROCEDURE public.set_name();
 -   DROP TRIGGER set_name ON mymes.malfunctions;
       mymes       cbtpost    false    373    235            �           2620    27059    mnt_plans set_name    TRIGGER     k   CREATE TRIGGER set_name BEFORE INSERT ON mymes.mnt_plans FOR EACH ROW EXECUTE PROCEDURE public.set_name();
 *   DROP TRIGGER set_name ON mymes.mnt_plans;
       mymes       cbtpost    false    248    373            �           2620    27060    process set_name    TRIGGER     i   CREATE TRIGGER set_name BEFORE INSERT ON mymes.process FOR EACH ROW EXECUTE PROCEDURE public.set_name();
 (   DROP TRIGGER set_name ON mymes.process;
       mymes       admin    false    273    373            �           2620    27265    fault_type set_name    TRIGGER     l   CREATE TRIGGER set_name BEFORE INSERT ON mymes.fault_type FOR EACH ROW EXECUTE PROCEDURE public.set_name();
 +   DROP TRIGGER set_name ON mymes.fault_type;
       mymes       admin    false    373    309            �           2620    27479    work_report set_sig_date    TRIGGER     }   CREATE TRIGGER set_sig_date BEFORE INSERT ON mymes.work_report FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_sig_date();
 0   DROP TRIGGER set_sig_date ON mymes.work_report;
       mymes       admin    false    286    385            �           2620    27480    fault set_sig_date    TRIGGER     w   CREATE TRIGGER set_sig_date BEFORE INSERT ON mymes.fault FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_sig_date();
 *   DROP TRIGGER set_sig_date ON mymes.fault;
       mymes       admin    false    385    313            |           2620    26987    part set_timestamp    TRIGGER     x   CREATE TRIGGER set_timestamp BEFORE UPDATE ON mymes.part FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_timestamp();
 *   DROP TRIGGER set_timestamp ON mymes.part;
       mymes       cbtpost    false    374    212            �           2620    27462    lot_swap update_updated_at    TRIGGER     �   CREATE TRIGGER update_updated_at BEFORE INSERT ON mymes.lot_swap FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_timestamp();
 2   DROP TRIGGER update_updated_at ON mymes.lot_swap;
       mymes       admin    false    374    334            a           2606    25847 "   actions_t actions_t_action_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.actions_t
    ADD CONSTRAINT actions_t_action_id_fkey FOREIGN KEY (action_id) REFERENCES mymes.actions(id) ON DELETE CASCADE;
 K   ALTER TABLE ONLY mymes.actions_t DROP CONSTRAINT actions_t_action_id_fkey;
       mymes       admin    false    261    3524    262            N           2606    25773 :   availabilities availabilities_availability_profile_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.availabilities
    ADD CONSTRAINT availabilities_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE CASCADE;
 c   ALTER TABLE ONLY mymes.availabilities DROP CONSTRAINT availabilities_availability_profile_id_fkey;
       mymes       cbtpost    false    223    224    3485            O           2606    25887 :   availability_profiles_t availability_profiles_t_ap_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.availability_profiles_t
    ADD CONSTRAINT availability_profiles_t_ap_id_fkey FOREIGN KEY (ap_id) REFERENCES mymes.availability_profiles(id) ON DELETE CASCADE;
 c   ALTER TABLE ONLY mymes.availability_profiles_t DROP CONSTRAINT availability_profiles_t_ap_id_fkey;
       mymes       cbtpost    false    3485    227    223            j           2606    25992    bom bom_parent_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.bom
    ADD CONSTRAINT bom_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES mymes.part(id) ON DELETE RESTRICT;
 ?   ALTER TABLE ONLY mymes.bom DROP CONSTRAINT bom_parent_id_fkey;
       mymes       admin    false    280    212    3455            D           2606    25892 (   departments_t departments_t_dept_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.departments_t
    ADD CONSTRAINT departments_t_dept_id_fkey FOREIGN KEY (dept_id) REFERENCES mymes.departments(id) ON DELETE CASCADE;
 Q   ALTER TABLE ONLY mymes.departments_t DROP CONSTRAINT departments_t_dept_id_fkey;
       mymes       cbtpost    false    3447    209    207            I           2606    26160 0   employees employees_availability_profile_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE RESTRICT;
 Y   ALTER TABLE ONLY mymes.employees DROP CONSTRAINT employees_availability_profile_id_fkey;
       mymes       cbtpost    false    3485    219    223            K           2606    26380 $   employees employees_position_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_position_id_fkey FOREIGN KEY (position_id) REFERENCES mymes.positions(id) ON DELETE RESTRICT;
 M   ALTER TABLE ONLY mymes.employees DROP CONSTRAINT employees_position_id_fkey;
       mymes       cbtpost    false    301    219    3587            A           2606    25901 #   employees_t employees_t_emp_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.employees_t
    ADD CONSTRAINT employees_t_emp_id_fkey FOREIGN KEY (emp_id) REFERENCES mymes.employees(id) ON DELETE CASCADE;
 L   ALTER TABLE ONLY mymes.employees_t DROP CONSTRAINT employees_t_emp_id_fkey;
       mymes       cbtpost    false    3467    202    219            J           2606    26032     employees employees_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.employees
    ADD CONSTRAINT employees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;
 I   ALTER TABLE ONLY mymes.employees DROP CONSTRAINT employees_user_id_fkey;
       mymes       cbtpost    false    200    3437    219            L           2606    26069 2   equipments equipments_availability_profile_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.equipments
    ADD CONSTRAINT equipments_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE RESTRICT;
 [   ALTER TABLE ONLY mymes.equipments DROP CONSTRAINT equipments_availability_profile_id_fkey;
       mymes       cbtpost    false    220    3485    223            B           2606    25913 +   equipments_t equipments_t_equipment_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.equipments_t
    ADD CONSTRAINT equipments_t_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES mymes.equipments(id) ON DELETE CASCADE;
 T   ALTER TABLE ONLY mymes.equipments_t DROP CONSTRAINT equipments_t_equipment_id_fkey;
       mymes       cbtpost    false    3473    220    203            s           2606    27404    fault fault_fix_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_fix_id_fkey FOREIGN KEY (fix_id) REFERENCES mymes.fix(id) ON DELETE RESTRICT;
 @   ALTER TABLE ONLY mymes.fault DROP CONSTRAINT fault_fix_id_fkey;
       mymes       admin    false    3632    313    326            p           2606    26627    fault fault_serial_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE RESTRICT;
 C   ALTER TABLE ONLY mymes.fault DROP CONSTRAINT fault_serial_id_fkey;
       mymes       admin    false    3517    258    313            q           2606    26632    fault fault_status_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_status_id_fkey FOREIGN KEY (fault_status_id) REFERENCES mymes.fault_status(id) ON DELETE RESTRICT;
 C   ALTER TABLE ONLY mymes.fault DROP CONSTRAINT fault_status_id_fkey;
       mymes       admin    false    3605    311    313            y           2606    27391 0   fault_type_act fault_type_act_fault_type_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fault_type_act
    ADD CONSTRAINT fault_type_act_fault_type_id_fkey FOREIGN KEY (fault_type_id) REFERENCES mymes.fault_type(id) ON DELETE RESTRICT;
 Y   ALTER TABLE ONLY mymes.fault_type_act DROP CONSTRAINT fault_type_act_fault_type_id_fkey;
       mymes       admin    false    309    3601    323            r           2606    26637    fault fault_type_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fault
    ADD CONSTRAINT fault_type_id_fkey FOREIGN KEY (fault_type_id) REFERENCES mymes.fault_type(id) ON DELETE RESTRICT;
 A   ALTER TABLE ONLY mymes.fault DROP CONSTRAINT fault_type_id_fkey;
       mymes       admin    false    3601    313    309            {           2606    27396    fix_act fix_act_fix_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fix_act
    ADD CONSTRAINT fix_act_fix_id_fkey FOREIGN KEY (fix_id) REFERENCES mymes.fix(id) ON DELETE RESTRICT;
 D   ALTER TABLE ONLY mymes.fix_act DROP CONSTRAINT fix_act_fix_id_fkey;
       mymes       admin    false    326    330    3632            z           2606    27374    fix_t fix_t_fix_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fix_t
    ADD CONSTRAINT fix_t_fix_id_fkey FOREIGN KEY (fix_id) REFERENCES mymes.fix(id) ON DELETE CASCADE;
 @   ALTER TABLE ONLY mymes.fix_t DROP CONSTRAINT fix_t_fix_id_fkey;
       mymes       admin    false    326    3632    328            w           2606    26806 4   identifier_links identifier_links_identifier_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.identifier_links
    ADD CONSTRAINT identifier_links_identifier_id_fkey FOREIGN KEY (identifier_id) REFERENCES mymes.identifier(id) ON DELETE CASCADE;
 ]   ALTER TABLE ONLY mymes.identifier_links DROP CONSTRAINT identifier_links_identifier_id_fkey;
       mymes       admin    false    3575    288    318            x           2606    35793 0   identifier_links identifier_links_parent_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.identifier_links
    ADD CONSTRAINT identifier_links_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES mymes.work_report(id) NOT VALID;
 Y   ALTER TABLE ONLY mymes.identifier_links DROP CONSTRAINT identifier_links_parent_id_fkey;
       mymes       admin    false    3571    286    318            o           2606    27299 /   identifier identifier_parent_identifier_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.identifier
    ADD CONSTRAINT identifier_parent_identifier_id_fkey FOREIGN KEY (parent_identifier_id) REFERENCES mymes.identifier(id) ON DELETE RESTRICT;
 X   ALTER TABLE ONLY mymes.identifier DROP CONSTRAINT identifier_parent_identifier_id_fkey;
       mymes       admin    false    3575    288    288            c           2606    25918 7   import_schamas_t import_schamas_t_import_schama_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.import_schamas_t
    ADD CONSTRAINT import_schamas_t_import_schama_id_fkey FOREIGN KEY (import_schama_id) REFERENCES mymes.import_schemas(id) ON DELETE CASCADE;
 `   ALTER TABLE ONLY mymes.import_schamas_t DROP CONSTRAINT import_schamas_t_import_schama_id_fkey;
       mymes       admin    false    266    3532    265            b           2606    25842    kit kit_serial_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.kit
    ADD CONSTRAINT kit_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE RESTRICT;
 ?   ALTER TABLE ONLY mymes.kit DROP CONSTRAINT kit_serial_id_fkey;
       mymes       admin    false    258    3517    263            k           2606    25923 4   local_actions_t local_actions_t_local_action_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.local_actions_t
    ADD CONSTRAINT local_actions_t_local_action_id_fkey FOREIGN KEY (local_action_id) REFERENCES mymes.local_actions(id) ON DELETE CASCADE;
 ]   ALTER TABLE ONLY mymes.local_actions_t DROP CONSTRAINT local_actions_t_local_action_id_fkey;
       mymes       admin    false    3565    284    283            _           2606    26170    locations locations_act_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.locations
    ADD CONSTRAINT locations_act_id_fkey FOREIGN KEY (act_id) REFERENCES mymes.actions(id) ON DELETE RESTRICT;
 H   ALTER TABLE ONLY mymes.locations DROP CONSTRAINT locations_act_id_fkey;
       mymes       admin    false    3524    259    261            `           2606    25997     locations locations_part_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.locations
    ADD CONSTRAINT locations_part_id_fkey FOREIGN KEY (part_id) REFERENCES mymes.part(id) ON DELETE RESTRICT;
 I   ALTER TABLE ONLY mymes.locations DROP CONSTRAINT locations_part_id_fkey;
       mymes       admin    false    259    212    3455            u           2606    26597 0   fault_status_t malf_status_t_malf_status_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fault_status_t
    ADD CONSTRAINT malf_status_t_malf_status_id_fkey FOREIGN KEY (fault_status_id) REFERENCES mymes.fault_status(id) ON DELETE CASCADE;
 Y   ALTER TABLE ONLY mymes.fault_status_t DROP CONSTRAINT malf_status_t_malf_status_id_fkey;
       mymes       admin    false    311    3605    315            v           2606    26842    fault_t malf_t_malf_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fault_t
    ADD CONSTRAINT malf_t_malf_id_fkey FOREIGN KEY (fault_id) REFERENCES mymes.fault(id) ON DELETE CASCADE;
 D   ALTER TABLE ONLY mymes.fault_t DROP CONSTRAINT malf_t_malf_id_fkey;
       mymes       admin    false    3609    316    313            t           2606    26602 *   fault_type_t malf_type_t_malf_type_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.fault_type_t
    ADD CONSTRAINT malf_type_t_malf_type_id_fkey FOREIGN KEY (fault_type_id) REFERENCES mymes.fault_type(id) ON DELETE CASCADE;
 S   ALTER TABLE ONLY mymes.fault_type_t DROP CONSTRAINT malf_type_t_malf_type_id_fkey;
       mymes       admin    false    3601    314    309            T           2606    25933 @   malfunction_types_t malfunction_types_t_malfunction_type_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.malfunction_types_t
    ADD CONSTRAINT malfunction_types_t_malfunction_type_id_fkey FOREIGN KEY (malfunction_type_id) REFERENCES mymes.malfunction_types(id) ON DELETE CASCADE;
 i   ALTER TABLE ONLY mymes.malfunction_types_t DROP CONSTRAINT malfunction_types_t_malfunction_type_id_fkey;
       mymes       cbtpost    false    241    237    3499            R           2606    26027 +   malfunctions malfunctions_equipment_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.malfunctions
    ADD CONSTRAINT malfunctions_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES mymes.equipments(id) ON DELETE RESTRICT;
 T   ALTER TABLE ONLY mymes.malfunctions DROP CONSTRAINT malfunctions_equipment_id_fkey;
       mymes       cbtpost    false    235    220    3473            Q           2606    26022 2   malfunctions malfunctions_malfunction_type_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.malfunctions
    ADD CONSTRAINT malfunctions_malfunction_type_id_fkey FOREIGN KEY (malfunction_type_id) REFERENCES mymes.malfunction_types(id) ON DELETE RESTRICT;
 [   ALTER TABLE ONLY mymes.malfunctions DROP CONSTRAINT malfunctions_malfunction_type_id_fkey;
       mymes       cbtpost    false    3499    235    237            S           2606    25938 1   malfunctions_t malfunctions_t_malfunction_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.malfunctions_t
    ADD CONSTRAINT malfunctions_t_malfunction_id_fkey FOREIGN KEY (malfunction_id) REFERENCES mymes.malfunctions(id) ON DELETE CASCADE;
 Z   ALTER TABLE ONLY mymes.malfunctions_t DROP CONSTRAINT malfunctions_t_malfunction_id_fkey;
       mymes       cbtpost    false    238    3497    235            Y           2606    26017 .   mnt_plan_items mnt_plan_items_mnt_plan_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.mnt_plan_items
    ADD CONSTRAINT mnt_plan_items_mnt_plan_id_fkey FOREIGN KEY (mnt_plan_id) REFERENCES mymes.mnt_plans(id) ON DELETE RESTRICT;
 W   ALTER TABLE ONLY mymes.mnt_plan_items DROP CONSTRAINT mnt_plan_items_mnt_plan_id_fkey;
       mymes       cbtpost    false    249    248    3507            Z           2606    25943 (   mnt_plans_t mnt_plans_t_mnt_plan_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.mnt_plans_t
    ADD CONSTRAINT mnt_plans_t_mnt_plan_id_fkey FOREIGN KEY (mnt_plan_id) REFERENCES mymes.mnt_plans(id) ON DELETE CASCADE;
 Q   ALTER TABLE ONLY mymes.mnt_plans_t DROP CONSTRAINT mnt_plans_t_mnt_plan_id_fkey;
       mymes       cbtpost    false    3507    250    248            E           2606    26180    part part_part_status_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.part
    ADD CONSTRAINT part_part_status_id_fkey FOREIGN KEY (part_status_id) REFERENCES mymes.part_status(id) ON DELETE RESTRICT;
 F   ALTER TABLE ONLY mymes.part DROP CONSTRAINT part_part_status_id_fkey;
       mymes       cbtpost    false    3457    215    212            G           2606    25948 /   part_status_t part_status_t_part_status_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.part_status_t
    ADD CONSTRAINT part_status_t_part_status_id_fkey FOREIGN KEY (part_status_id) REFERENCES mymes.part_status(id) ON DELETE CASCADE;
 X   ALTER TABLE ONLY mymes.part_status_t DROP CONSTRAINT part_status_t_part_status_id_fkey;
       mymes       cbtpost    false    3457    215    216            F           2606    25953    part_t part_t_part_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.part_t
    ADD CONSTRAINT part_t_part_id_fkey FOREIGN KEY (part_id) REFERENCES mymes.part(id) ON DELETE CASCADE;
 C   ALTER TABLE ONLY mymes.part_t DROP CONSTRAINT part_t_part_id_fkey;
       mymes       cbtpost    false    3455    212    213            h           2606    26012    proc_act proc_act_act_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_act_id_fkey FOREIGN KEY (act_id) REFERENCES mymes.actions(id) ON DELETE RESTRICT;
 F   ALTER TABLE ONLY mymes.proc_act DROP CONSTRAINT proc_act_act_id_fkey;
       mymes       admin    false    276    261    3524            g           2606    26007 !   proc_act proc_act_process_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.proc_act
    ADD CONSTRAINT proc_act_process_id_fkey FOREIGN KEY (process_id) REFERENCES mymes.process(id) ON DELETE RESTRICT;
 J   ALTER TABLE ONLY mymes.proc_act DROP CONSTRAINT proc_act_process_id_fkey;
       mymes       admin    false    273    276    3546            f           2606    25958 #   process_t process_t_process_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.process_t
    ADD CONSTRAINT process_t_process_id_fkey FOREIGN KEY (process_id) REFERENCES mymes.process(id) ON DELETE CASCADE;
 L   ALTER TABLE ONLY mymes.process_t DROP CONSTRAINT process_t_process_id_fkey;
       mymes       admin    false    3546    273    274            X           2606    25963 1   repair_types_t repair_types_t_repair_type_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.repair_types_t
    ADD CONSTRAINT repair_types_t_repair_type_id_fkey FOREIGN KEY (repair_type_id) REFERENCES mymes.repair_types(id) ON DELETE CASCADE;
 Z   ALTER TABLE ONLY mymes.repair_types_t DROP CONSTRAINT repair_types_t_repair_type_id_fkey;
       mymes       cbtpost    false    245    246    3505            V           2606    26103     repairs repairs_employee_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.repairs
    ADD CONSTRAINT repairs_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES mymes.employees(id) ON DELETE RESTRICT;
 I   ALTER TABLE ONLY mymes.repairs DROP CONSTRAINT repairs_employee_id_fkey;
       mymes       cbtpost    false    243    219    3467            U           2606    26098 #   repairs repairs_malfunction_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.repairs
    ADD CONSTRAINT repairs_malfunction_id_fkey FOREIGN KEY (malfunction_id) REFERENCES mymes.malfunctions(id) ON DELETE RESTRICT;
 L   ALTER TABLE ONLY mymes.repairs DROP CONSTRAINT repairs_malfunction_id_fkey;
       mymes       cbtpost    false    235    243    3497            W           2606    26108 #   repairs repairs_repair_type_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.repairs
    ADD CONSTRAINT repairs_repair_type_id_fkey FOREIGN KEY (repair_type_id) REFERENCES mymes.repair_types(id) ON DELETE RESTRICT;
 L   ALTER TABLE ONLY mymes.repairs DROP CONSTRAINT repairs_repair_type_id_fkey;
       mymes       cbtpost    false    245    3505    243            M           2606    26140 <   resource_groups resource_groups_availability_profile_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.resource_groups
    ADD CONSTRAINT resource_groups_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE RESTRICT;
 e   ALTER TABLE ONLY mymes.resource_groups DROP CONSTRAINT resource_groups_availability_profile_id_fkey;
       mymes       cbtpost    false    221    223    3485            C           2606    25975 :   resource_groups_t resource_groups_t_resource_group_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.resource_groups_t
    ADD CONSTRAINT resource_groups_t_resource_group_id_fkey FOREIGN KEY (resource_group_id) REFERENCES mymes.resource_groups(id) ON DELETE CASCADE;
 c   ALTER TABLE ONLY mymes.resource_groups_t DROP CONSTRAINT resource_groups_t_resource_group_id_fkey;
       mymes       cbtpost    false    205    221    3479            H           2606    26037 0   resources resources_availability_profile_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.resources
    ADD CONSTRAINT resources_availability_profile_id_fkey FOREIGN KEY (availability_profile_id) REFERENCES mymes.availability_profiles(id) ON DELETE RESTRICT;
 Y   ALTER TABLE ONLY mymes.resources DROP CONSTRAINT resources_availability_profile_id_fkey;
       mymes       cbtpost    false    218    223    3485            i           2606    25643 $   serial_act serial_act_serial_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.serial_act
    ADD CONSTRAINT serial_act_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE CASCADE;
 M   ALTER TABLE ONLY mymes.serial_act DROP CONSTRAINT serial_act_serial_id_fkey;
       mymes       admin    false    258    278    3517            d           2606    25982 9   serial_statuses_t serial_statuses_t_serial_status_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.serial_statuses_t
    ADD CONSTRAINT serial_statuses_t_serial_status_id_fkey FOREIGN KEY (serial_status_id) REFERENCES mymes.serial_statuses(id) ON DELETE CASCADE;
 b   ALTER TABLE ONLY mymes.serial_statuses_t DROP CONSTRAINT serial_statuses_t_serial_status_id_fkey;
       mymes       admin    false    269    3536    268            \           2606    26436 "   serials serials_parent_serial_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_parent_serial_fkey FOREIGN KEY (parent_serial) REFERENCES mymes.serials(id) ON DELETE RESTRICT;
 K   ALTER TABLE ONLY mymes.serials DROP CONSTRAINT serials_parent_serial_fkey;
       mymes       admin    false    258    258    3517            ]           2606    26115    serials serials_part_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_part_id_fkey FOREIGN KEY (part_id) REFERENCES mymes.part(id) ON DELETE RESTRICT;
 E   ALTER TABLE ONLY mymes.serials DROP CONSTRAINT serials_part_id_fkey;
       mymes       admin    false    258    212    3455            ^           2606    26120    serials serials_process_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_process_id_fkey FOREIGN KEY (process_id) REFERENCES mymes.process(id) ON DELETE RESTRICT;
 H   ALTER TABLE ONLY mymes.serials DROP CONSTRAINT serials_process_id_fkey;
       mymes       admin    false    273    3546    258            [           2606    26195    serials serials_status_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.serials
    ADD CONSTRAINT serials_status_fkey FOREIGN KEY (status) REFERENCES mymes.serial_statuses(id) ON DELETE RESTRICT;
 D   ALTER TABLE ONLY mymes.serials DROP CONSTRAINT serials_status_fkey;
       mymes       admin    false    258    3536    268            e           2606    25827 "   serials_t serials_t_serial_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.serials_t
    ADD CONSTRAINT serials_t_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE CASCADE;
 K   ALTER TABLE ONLY mymes.serials_t DROP CONSTRAINT serials_t_serial_id_fkey;
       mymes       admin    false    3517    258    270            P           2606    25987 9   standards_types_t standards_types_t_standard_type_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.standards_types_t
    ADD CONSTRAINT standards_types_t_standard_type_id_fkey FOREIGN KEY (standard_type_id) REFERENCES mymes.standards(id) ON DELETE CASCADE;
 b   ALTER TABLE ONLY mymes.standards_types_t DROP CONSTRAINT standards_types_t_standard_type_id_fkey;
       mymes       cbtpost    false    3493    230    233            m           2606    26125 #   work_report work_report_act_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_act_id_fkey FOREIGN KEY (act_id) REFERENCES mymes.actions(id) ON DELETE RESTRICT;
 L   ALTER TABLE ONLY mymes.work_report DROP CONSTRAINT work_report_act_id_fkey;
       mymes       admin    false    3524    286    261            l           2606    25808 &   work_report work_report_serial_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES mymes.serials(id) ON DELETE RESTRICT;
 O   ALTER TABLE ONLY mymes.work_report DROP CONSTRAINT work_report_serial_id_fkey;
       mymes       admin    false    286    3517    258            n           2606    26130 %   work_report work_report_sig_user_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mymes.work_report
    ADD CONSTRAINT work_report_sig_user_fkey FOREIGN KEY (sig_user) REFERENCES public.users(id) ON DELETE RESTRICT;
 N   ALTER TABLE ONLY mymes.work_report DROP CONSTRAINT work_report_sig_user_fkey;
       mymes       admin    false    3437    286    200            i   
   x���          �     x�����7�{_�[&�H"5#a�),��&�6X$.�0�I����3���¯�Q��#���?|��_���_�O}�������ϟ?~���Ͽ|�����������+�/��?�}�~�����_����?���W�����Տ��y�_��݇���� X���h�C<g���B!t���<�����"Xl�kvM �q-�P'&
�X	d|��� ��޿�v�_���������	���5n������^��k��E �޹����I ���>�=k<{���o�K,Gl��k�l�"��eL@�/Ɨi����X����"tba�����O+׉�����؟��8��g�?�8��噫���P.T�\P 7sg�?�7j*5>��00��a��G���������_%��  ���C�d�JA)��_��|b�mЩqwc����ޝ1�!�>���a<F8u ������,lO�}���r��'��䶏ȟ��:ľ�'��(�ڠo��7��1~o��^/��y�
��u��3��YGX7��.���T*�L��yy�լAn^����
i��۴7���b'��Y�B褔�S�"��R(B7RJB���ֵ>I)�O?H)	�i%�!���`D)�#b�b@G���R��*&A3	��N}?���,�k��\] H���T�)���H �
��d��'���̳�i]^��� �;�k��C�PY�n�7���UBDQ���("9�dQ$ Ģ���w*y=oo���Tu"���!ǙR�%p(N)	�ɔ�i:�����5���e'�*��b�	�t�5q��`8��	A��%!��&�cD~����#>~R����8��MK ���!��T]��I!T�c����w�1@��P�J{5���}L.�ӹ��h#ɜ��2��ܝ�����Ѥ|�	�Dcq��%#�de�~�'� ��*�,�\<��A���kpS(#��@�]���"�"s�*�,H�ד�^�B+oNaA+!(B�d &��@L��6�%�彥M�J�bԶ��o�����M���� �JrZ���a4� �V�� �BD�Q:�ʁ�Eݙa�:@�*���3
*h��`����I��`6J���|:y34@J~:�N��D����+�>@�st� ���3[y�A1|�pCM��2K�ҝ
���0�Ǎo/�#%�y�N�8;(c�5������y{�^�)�U/�������p��މ`P譚O��a�qڄ�� ���O,�$Rk�T�B�Boqbd�L�a�Q:���v�E�t"9�A҉
��.�E�t"��A҉
J��^
Q9�"K�Cщ$�D�Rd���p�O���@�D�@��jR1I?�d)K�F�ŘP)+�R�b�;�����$�t"@~:������ P)�Ua��8Eb��������s ⚌#/�!�mė�Hw"��i���P͏j�����Y�0=N�RNv+7}Bn:W:$tBnZ�AE�?�u(�@���4E K1�DN2���{'H�]c�P�;�}�b��;d]�yZ.:��9
(���
(Ǣ�ӳʱ�ZV!��,E2X��v��E���6܋����釽����~xڍplTg(f� �:�'�/����F&�4HY!�42��A�Ȅ`��1�F��d0���Rg�hdZ�D�b�Y�ͨ>Q�B���m��%/�6]d��B�rd����!?-2y�C�C](� �g�:���T'���w0k,u3��Ub�$E�J1i�B�QMB
gT���H��T����  G��)֚j��a��t%��NKVmk���!8��~�Ɔr[�(���
�@�ß���F�p�l*\x8��-i\�|;d�r�Cל:�ߗ���2x"Pep�!<�S7:��@���kY� �\q�aԖ;��I�gE2F���9��)�0�Sά(�&HW+�F��Vc���B�h�Z���-!%�n%uZ��A�3�]�~H���}Y2k�zU$&r��u��v@:���x�K�o���L�HX`\��Qo}�ہ�I�(١�%)�B )��Eh'{HA�ި�H�d���X2S�gأi�FX`�L��QԖ�*��v^�5�ڒ�{�2�Q[ZmT�^P�X���E<�Z^0HFW� �0�ɪ��j`$1)��50
ӧ���ԅ V�M1m�J]P�:WzV�Ƚ�ĐZ(-�5�x�A��D�g�yU�#����"��nPb� $((:.�3 �#oBD��Bp�R�~@�x��jdT�z=�ɨ �~P��Վ�,�[�I�U'���6I���`!��&	��XuR��X4���A���)�^�ms�E����f��jP�)Qq�*��$�F6ɩnF�?ԃh�j��h��b��i��`?��jg�IxWKf�҈�S趑�Z�8��W����0���{���=$5�"41G"���Լ�1B�~�{Hj�N�姝j֓�Cb+��� �A����D M�f�d4�~��v��/�i�M�r:�R�#yR]�w�}�|�(!���jh䓼��R~��T�� ]i"P�48��X
�������| ��wrrN���v�6,�%Ka�`��B�n �A�S��D��v��h��'�8�$[!�u\��d��E먳��f#��� B��1��,7�L��M`��� P�~���`�)�Q�����s�| �G�G�	�������c���aC/D��"h���ܭ }c<���)vSF�	���x�)zS�:�'���K';�D.1���Z묊�gC9�3������|����=�ߤ      �   �  x�ŗ]O�0������8���j)Eǜ[��4Ru	_nCQ��]�@ ������{�>9��m�1�(�z��_S����"��r�H���)�P�^se��Q��R�!F�-Dh��%�i��lγ�M�o�DC�OH�ݎ���'nP�O���WFz-ْoi^�$�zh^׼J(;-A��2�6_��@���W��X�0 ��q�4���J5)���^����I2K�!��?q��{B�Bh���
�&7��)j�e/��EW�*���.��6�R ��#K����
�F����Ox��ʏ�^�v��^$1cB�А̵�Q�@�l T
�-i��#Q\f<y6*�<��yTo/��Z�V�9��4��f[S�Kʅm��jk�V���#��(eW �.�30j	 a�\zʀ�06�ZAik |
%��,���d:�w���E�d^�[W��17�VApʫM�� �N^,þɑ�@t�1�K��������t������j�?�a*�      �   (  x���͎�0 �;O1=�+���$��(kڨ�����,�HV$��g顏����Ti{��EB|38�3�|n��B>�8�>����v��i7܅�M]�����C����~�~p�tZjw� � ��Ӯ���?�r./�˟�� �Ɛn�ʵ���
�>.��]�*��<��{x:��=�o�d�Dģ\�`_��;�[w �ێ1�C�7��gN~<v���G�+���D���Ev-3�"0�Qkw���On�h:�f:�
�1?6/�b�0�_�g0�.y]%䢄��8��6J٣���a=
����/���M�{w�R�W?�#�{���4�ƫ*�U��F۲�e��M>��ef
��*!%���:d̮rQ�Ű�t����vrk��p���ea��~Y�qéT��/�B2�5ւP4 ����5����&��ń�T&2�1�����z�l��9/�X��Ej��^XI�(��`��=Pe���	�М��ͼ��[�"s[I]h����Ҭ,g�:��>
�Jҧ*�-��S�cG7J�:m���}m�?���T�      g   �  x�ŘOk�@��~���Jv7;���<b�j�!Ť�&�����kt5k��#��Ǽy�'��r��b���U�*�=�?iQ�EY�l�F��C��̒b��,�ڤ���ۺJ�E�l_۠y!/�Ϥ����z�d#
��0��ox-����y0{ WS(�"�cy��&��+��2����'G=��4Ae��
����5�(���^�������Ma���T9��ZJ������ҵ�_�~�_��P{g��������Y�E0�E=���FE=T�RaZ��6���6��iK�
�?A�Is��F@A�7�,������	ӯy띃�A�1�A{h��1"7��s�Թ�����(O�]�x(�B�v=�@i��߹$@�2ުRF��@���X*	���+�+ch��ސS�+�:} ⱌ.TG����)����s�      f   �   x���v
Q���Wȭ�M-�K,K��IL���,��/(�O��I-V��L�Q�K�M�QHL.�,�%���:
E���%���
a�>���
:
�F&���@%E�@�~�>>@1l�kZsyR�	��@�|��2����%�@��2�3J��P�.-ʬU��S̐�d��brLHjq	�Q�� )��      j   1  x���AK�0�����؊N���`��]���4Q��P�A��@p���c��e�xy;�rx?������"�(N�A���=vǄd�B
�fuSͅ�:30du&f≯�iDmDU� Y���\MN/�	�|�UM)��B����|8�x;��k�k�\�;� �v��sC��rc��KeJ�r�����z[�:�d�8ٽP�
&}'��҂��(L��1\� BBE���6�����si�n�(�me�p�BGp�^Ye�I	��*X�4S�(��)\݀�g�/������}��y�~�Q�      �      x��}Mo]G��� P7��ʈ�O��)�2E��GK��j��@SUӮ�n�����x�����\ؒ<μ�q">>�==������?��?������_�����W�珿~������������W���o�����_����/�>_�����?��������Cx�������_>}����O���=�b��$H�hw�~3�S���:����+�C�q�9�K��@I*�S%�P%B���Ʌ��PV ����uŨi9��A�~���Et:�,?a����)�y��'�ruy���S3X�0� �%5�dxB\nPD�r�P�.��;T�O^�C.��X�q~�T�BNU�l��0�^�u}(�l��1�_�[���[̷jb�t�I�Y��0aJ��6WT	�@E�a*!!H���*�8����X���s*�k\��ȘR⊀*%� ���P��$
����0Ȩr8�X
seLΕAqY�@YN#��,y�~���5.ļ(��������?~����a�F?NW�7��Pk� �v�O(���q�o�w�6℉"�m͍A�2.%��Ʈ�J)Rj�~�7�7з_4�)~������շ������8���{�qeK	)��۟b���B�e�jL�Z���QT��J�r��Kȡ��uC@�<����ێߩ�AZ�^r�\ 5��ޣJJ��d�hV=��`u߲XZ����:-Tl�2$�P��j�� �E"��X��(�z���������7F��K���:��0�L�j��wQ����+�92�Ѕ�8)VՈ7��Tkw1c�QkQ�U�+�Xq�Zj)B�ٱ����S&�n��0�zR�%b=I�D[,���z�ôx �%&�K����q�Ҫh�!O�E�w��V�e��NH#����5_�(΃>�4�%oB���8�~�*��ܢ2%���%XOd*ȭHZ�%0_�%�
y��X�`���I���]3m�ؽ.б���w�{A���%�RL�����5^�2Kaϗ��oWq�����F��=ƇI&����w�%�# ��� ���� &�Ɛ,�n��(��R��(�%���>�c:
�nޱ�+jV�D��Q$�����;G�Z��Q��bP�Te�d�t�v�|�5�_�d+A�t���	t.}�؜�����{ńɌ�fF�s��{�K�˄�.C�F6�����Ҥ_��S��aw���r��
r�4^�����w�ǥ��ة�;�'KZXO6�FR�Mj�W��>~x��;b���^�y�Ij6��
1QI�t��6,�څ�0��qR���KĈ��6�����-Q�F��b��jy�ҟ�{ޗ��f��ˌ#��[6PZ~ �*�@]���b)�J ��`1Mj)
����S/j]2N����o������,����|�a�1�Q�,P\��4J�o>�^�á&���ع�$`��4�/��x�E#f���R-�%FQ'��`�eH�^N�B5�9�)�Q� ���\�7�Z����4 H���L\3��f��æ�F�n�0P�B5��ʥ(´��:1}��ʑ�etK�8�\-�B4��= �m�- _�s����������!7�(�bK�VL�C	�*!$�KRL�C!��U o��	ea#Z�
Y�j�g���88P�Ux>�ҏŘ�F�Y�2.�(�ڨ�T2��1Auъ�v�_f&��t�,�E	�2.K.��N/sQ~�
uʑ	�,Il������\���5&9@\sќ�$��̎\`�q��T ϥ����&]���:w��o�Se�;aù;��Mι�Q�g>�f�GI�`	c:�(D�*�Q�w(�0�2�����&Bn;�!�*�x:��u�:ͫ����.k��%��*
����w ��D�'R',�I�B��D��!�Xr���t����D�=���!�!n�ʁA-���*�[�LQA6}��2g�b�+�t���c�D����QQ�]$j9�`yy\C�:J��'*��(y�<�����X���ˡ�>�#e��Y�A4 ��j��8`�����&�c��$���W8L̛T����a���C*b���A��3�ɲ�R�L�.%�s�Ì��+2�\����ᨈ#�:�`��'4F^��L"�Me~�=�aY6�������4/3��?,�X�PB^�*���$�T�3g��k=&��Z�yu�X����ɏ��G!�lϥ+ �`��"�'������yb��oq-7,���_��*�j���p�+�`���?���T'��Y�{	�Ū��> �Xu.�s��J3ffeǲҬ� �#\=�<[r�t�������]1��	cS��ר��������"bJP:3ݵs$�z�L%�%��^0�ǗYVA��/��#V�ݧ���x�B�~<��D��q�|	y��a�?>~�����KHn|�|	�xs��'e���S�*�*>t���X`��+d\�f�N(@��E�\W7K\0u�1�k���9���
eBE��+ԧ�/��Pө��:�"�Ce�TL� �*݊5i t������x��Qb�&���k��W�Ӳ��T�����ph��X��,&��4��/�&&���/�-+�˃:a�F����>S*�^�A��Qfڀe��LZ�\9���w��.�W��=��*�ܮAM�4���
�0�ɲAb �j�Өc��@1�[�J�C!@;��Ld��,�xj�e��xc(��,���\��jva�t����C�]Y�Ze��[�b�@��s���aX�m���?̩�d-�ASnֲgm"�MS cn+cq!9����Y>-�۟\EvIi�8�BV�+�����C�X
;\]̾��fN�w��	�b5cH�eLf�r?1X�!�����6�b�0BK��-�Rvp6P���4�	G�=�6i��"�{Zr�PY1W�%�YYܕ��\<��t�L�$ɂ)̄:�	+��Ȝ��g(������:
�(�����	��53�t��fA,I�#>�t�S�b����<�չ�g�`4I���ӧ�` +��ڿ�-hO���Q�Lg�`�{C����5,�	�4k�ܜ�я�MD-n�QXeչD7�1�hrLG�G��7C$��O�x��4u�R���?O�-����&:���C�!wl�@S|%�4o+ԟ+y>�XE�`	�W���A_��)�`��4SH��ub��| ����P�-��O�Y,+����V6@�'bp�v�����G��J�6�:��1S�1]��f�Bw��f��ԛ���@��`�r�MS�N�҅�D�|4TKlӅ�+����������psП�]hd�"WHᏢD�tZ+�!y7̼�ٞ+�h'ѹC̖��k���DXK�Wm��)Z,�*�8��=aA&*v�fe4�$�Yq�7�m�2���&���ǎ�FJ�#a�K�g:|�{���C�A��ny>J��]N%�C?�DS`�-�1kfD��P�a��hɳL��ۏ��l�|�˲cTe��yGC��Fѫ$�8[��q4�(n�d��	
�5��8U�X.�'�茌��C�����S�8�؜	"ZrAp�]�(N�3���
V��U�٩�I�;��O���Dϑ����9�L�+MA��o�E���o'!H@x�ñ�	�)%��oڳ����Xw���d^��* ِ��9�#@��/��bf����7�W��s����Y��1��X�����-��  �dI�u�1�j���])�lm�V1 ���1e&���0��ԉ�}��g������Z��%C*�e̟�_�Ϡn�85"�zh!�J��`ִ���zt�C"���p�-�4>����JN
�̴�i��i��T�v��:o3���f,��*�~q��Hn.j9�̝������8���]̞��5/N��4b9��sY?���9��US�h�7��+NX����<��n�@��c��͈P[��\�[��$A]������%Я�b	f[ь5�(���0�cnuSG0�E$��/�"$��b�    ��Ҙ������`;|d��>�aѰ�z��л�<���R]0��V=�&0�7�Z��`ΔjƼ��f��6��VR� ��C<6�`L�4�}��'�b���i�66D� ���Gw���>C=j���D�6@ӈd+M}3���0����6��+��Yv���7�流{�����2+��ށ��6}_^۶��-S�C�������X����k4x�����	�@��G����V��"�s�UyL�������OC���C��|sS'��'�mU]:�0�x؞�\���@}��wd��^��~����꧛e����ɒ""�'1k��`&P$r��h��0�zH�O��sE��$ӹN�P@-gR-��-����A��c3�!�_�B��fAh
F8��+�	D9M����Ɉ�;��Q�`�J}Č��T���� ���p��(�`1F�m+�8 XhP����7P����9��f*�á �Zw�&���v�G��X����.S��u ��`a�e�f]3&�NM�E��}�B�f-G՘`9�u͕14��l�je�l�������ƾ�bbv�Q��r�F�D�Z�D��Y���ګ�5,�/VfO&�D�&L�-o�8�a**�l<ZH���0b͌��Rْ��13�;V�X�{!��H�,,o(M���q����H��R rüg�٥����_k >dϯ�����Cr4�,qY�h2YB���LA;aa�9�\�����h���ЯdbD
�g�F*���F2zN6 m ^�X����<���x��o� s�6T����dP�V�ɉC�	�͛��C�E̎6�V^�lrB-+���*4�n �l��lX¼�V&Dܽ�R�`����?�U�=�K��2$r�lw�Q����R!���;�o�P���!�B�fr`��h̻��
f{����eP�ʢ�P�H�#� P3�s�c!���c��:��JNK��砧�Sz��b����,�R�=��V�#�:G��N���H O��E"c&5���@�HC��Z��V �}�ƿ����������6�����P�i�������RJ�< �h^ �4ș�D��`��6Lm��Ve�ՒP���\'Nz�JB�vG�,>&�q��X��X�&;|b�'�-�����Y0*a��@��'�8��tJ���������բ���`��yN���cv�ч�ĵ�Y�'���F@��� �ݧ����GH歄ȅz�/v�,F�2J�'��է�!�u3��XbmY�v^~ 5'�L;�3���Վ�N��r�w3��_�s����əe�ZVf������_���/Q�\��;<я1�1�ĵ;�@���� �%�bWpf�8��(X5���XDL-�b��TJf�7S ]<��B�g�x�A��4v���g-2Vk��`*�q�Uy�����9�f\�UP��!�;�\&g'�iX��Xdå`�Fb�T�J����ɛn�3W���}Ɯ@�Y��}���3he%�h�P�D�$ �j��4J�(��]g�Pc��=�h��M�Q��ΩTLd(	�I�0mF��XC�;P�����u���K]�2��Gϧ���l�̇�� �%���
?�-w���� H�S�S	���<���͇�S��sD��	��põ"���R(`/>AU���0A�v���4|E�6c���8��	�`6TH�.����"T@P�^onf�\*���/D.�����	�h�XuFPDH�Z�rv�D�)U'���FR����,�jq�@ÆZp�@���,����,�� �%Ƙ-��c�*�f`����������.��m�rw*��;���I��PwE�oV�+hXo&g��DvQ`=g�L׊�ڱlMn�C6����7[��N��K<����*��g��T7�lkW�Xs�~ւ	q�<�d9@&�pdL5?��q��q�J�<��L�Ș����c2�MQ�kD�m"�= w2ڄ���^�.�b��O6�l��%gP@a�a�	S���#]C̯�%H�p�������_��m�f�/��g[�z�����U�4̫@nV��pλ����EV�����@��y��w|2��C��D;(��R��E�<싶H����P�!��.���0������T�,������d�@����H.��^_�\�C����+��nC@� �.$���
�� �',���\��������4�W�Gt�=N��c�i�C(�4��� b��jJ���f0fLYW��(3��M���(3ħt��(3��ߕy6���
i��Xm�j+a8ʤ̲*3��z�#��
6��|� �����2GAE��h2h�x�.2X�Y�ձ������v�-��bt�2��ܵ��[F�^���rNLFY�1f���N�_���zJL�"���xJ�Jv�t�H�~�<�mh�!`v�w]^#�%ۋ!��|�Qu�mֵ�A�Fr5�=@Ž�z0�8���h󉌁p��QgP�-�QgȻTW1v�$q�CҀ����s�
Q�g�؋i����3B�����X�z8
:���X��BU����Qi����ױ���|�ˤ�V>~�zw�:� ��3$�-��/~U���`E_����5=C,V�g�	0.c5�8��1H�:��w_)/� 6Z�����, �ѷ��g��+�+jd«!Q^t��!�&�9��Bj�L]�������Z�lkn_�C�X���`ݠ��_0f������?�Ϙ���f���~��	�G[����?�F� ������/��C~����:�lb>޼�~�D\@x��㔯0Bڌ�Q'q���7��f���P0ӊw���� ĺE��=�j��!l���� �t����?���@�+c:Uk`�Ƞ�oG3��Qj-��$5����k͠V���x�̤8�ꀳyyR����{�=��8�ݞݽ�Di5T�.�{LZ)��
�?"�+��O�	�7ؕ�C����jh�&ؕ�+��O� ���B�(%P�XjO������ 2T%���]B
���ٙXNz����V���P��=��ZCI)Ӗ�t��ll,��$㄀��15Z;�icci�QZ��Ќ�(�����/�l7��2ۙ���o�5��"�8}����w�<��!^a�$5�J쩈����]��K�ځ?�#���[��Hd���!伕��=�y��la���2�$�ʮx�S��+ƻ/��a�,�j���+�s�2.y[M[
����'�݉Т3��#5JhL�W�����6�����k	=<c��5�b�Ï%��{LWc-g�pB���wQq������y�]�0��f)��K�l?�,���#o6؟��m��1�Ϙ�(�&���ǟ��{:�+�_~<�{�z�)��g�^�'�3ky����v�T�A� a6��'�͗ۛ+
���cZ�Z��T����]F: =\-; � �|��f��mqe��'�!͐�.m�N�?����tM�\�p��cP&�nR�p��[�<��-k��~=ū�$۝0��J1����B��f�j��.f l�+.�Nb��х/��v�2��#dj|�ۺ�q�I����ͺ.A�B1��v:Afat�����l�a��k�fpZ��z��t���5cƖo�t1@2��*d�&K0�[��@�X�0�-��3Ϗ��e*\��ƪ�"`���\f<��Z@p��0|�*��P(^����1�M'����:��8���L1&ΏH�D�22�����<�5f�IN�N������M�5�W�"��Z�S6-�4��ye؄+!\O^?Vd��4����%Ȣ��Y�O�1��Xo�S���Ù��<�.�!����x�uV�����n�QdxJ�s?^���&΄l�H�AE�d�	U=�PgD�k�%{!�B��F�C��p~H:Vb����3]/}	EPy�_�~�{u��)�����Vc85]����p�n�&\3�l�������G��2�x�뙵k�+f��Մ�*�3�9j>℄�ˤ�!�t8�eL�I̫�Ǫ`.���s�n�a3y�i�]�	���������/=���9�B����(U$C�zi��~��m���O1}͇��݇�    nAy��!O]Ā�L��O�����Gf��� ��8یpƦ��@�^���7��	��gi
�f��x�0s����c%�L���Tt�(�^�l����)=/C �QL�d�O+-?~z>�U�:/�M������҂��0?�E%*�+�������4��`�DWc[�Tg��msߑf�l�~�L0i�����q�Z � 8�0�,f!���&�5�u�.��%�특M�]N Ѥ�]і��Y���L�l� K�XL����0F4��`�HD��x�SX���ӛ�7Fuy�9�]ѷ�Yz��ό�3V3(�
�	Qk�K��y�b*��!j#���� X�Ew��,&m�?H��B��}/�D���Y�ȱ�s.��E��l�/��6j��\�yM!�s(8O�D7X�yMK��+�e����v�-!��LдY{y!�R�M��	�b�"0o �����܇��&�v���g��ˌ\��֑GO�!�m/�.�o-�v�o�^����NҖ*�,�ch��WH���P�D�ih�JeB|��ka�6-A��u��U�ۇ{
�p����ӊt�
����݂�L.�ZԻӬ�^L�f!J>������1�A��U�������V�Q�ed@�'��(���}}���H���VfS���nħr�:�xZQ`ZXfC���盛�6s#h♋i� %,�pf��9\E)�\ ?�������.��">��f��U/�!�#P�z�� .��`'��3z
*߶*�N0��)�lfƸm��r�������q�؝o���Є3��� v�z�3h�a�;[�sNO	�ߪ�0��#pk�8fd�����V>+��ށ��ƞ�X&��!#_X�-�����E�O�v3S����m�@��t���ڎڇ��L(S⧛� F���~�
�U��G��,��Г��?\-���,݈��K�Xҽ��vD�̋���;�B0�L��e<%D;��ͨ�b*��2�	ѫ̜z�j�2���V�G�Z�e~ ���h��܁�2ф3��O�ۖe����?�!>a62���d�����3�����v�2��,;T6!/������;��t`>�п���o�6�n�tҔw�f&��5k�������R�b� �Թ'k������{�>�̯�QkˀN}��v�`b�_�G'��9�[�AK��t�X���X�9�� V����Z52�P�!��a�p"���T��x���p<�0��S6�S�P_�v��.'W��ao�N4��9���+�J��`w �fU����`�,��sq\&����$�1�F��
��9��m�C��*��u�D�-��C����2u�������w�ǅhэ"?C^��{��������D�c|�R���Y����҉a
0uISW6?-���\���lC��ұx���^PaI��_$����{��+���f-�2c]b[�e��� D���"�[�E�p�p�b��R,����õ�2�ͤ��A�W�%�0ģ�	�IĎ��M�6&���׍��l
g�ek1��2�	^ �;�%���p��[�p��<#��p�* ��]�9!��=�)��-:�c��(��T٨^��q�{�l�*��\�%��52e09��-C�R�^��ݷ�0w�?��?0Z����C�:$�� K�2�W4�C������޽3���\{X�S��
��+���N*�%�\�lI������;�p}�Ǫ��A0E�n��-��#i[T�~$��~!i?Rf4<�G*9H����Xڏ�� i?�����Z������+ۓQ�7i3�6�Ä��;l��Ѵ$m�>4MK���iZR�֐AiZR=%Ҵ����i�p��Ӵbm&<
�I���� J�1��ǆ�x�E,����cԴYi��2��f�)�#��E�`�v5u+X����A`�\c��|��|p�HIm�&DJ�[O�$DJ	[84!R��h��H�^9G���<!2�`��� qf�ssmdyL�g	��t�6~=�-�ּ�����TH-Et��+��;�Btc�++V��i�`ٽH۝;��P�59`�Y��P`�q� 62֭���%msV,�[rںU$�[�|<8��;U���H�ݫN�'qsR�;������^b� kE����vZto�W ��8�(�2��p޿�����Z���|z@�����<|`7]�&A�q�bo=�8�n��k�A�bRd�g�-����t{mJ��8�`r�Aw�$(����P���j�z����[Cݐ����m�7t�E������p�p�v�J���#/��,�%Í���4L"G^t�yƃ���VS[I~��'�T�X1`��I�E7XZ�
W�#����n�2~ҵ��g�:/�d� �y.�y��")�H�:�t��V$AXў+*=3\�!�u��ɤO4TT��S.���ٽ�JtY�6j�|Įu�jB��tFG0�s�8r��)��\��gH?SD[��2�n���wF	br���Ķ��~��~"j�Rt�� ��������bG��}B	�!��^Wu��V�A��h�y�8�B�x�N�ST����C>]����$���_�C>���ﾼ}�����@%ѹ��*#�JٯRS�z��`/���&��X����T��X�;p3D�:�\���>a����|+��`��F�V+s���/�� ya>�j ��v�󩭓�ˁ֮�}'�u�nV�u���c]ˢ�e ������ZV�{v�����fǍ�a�T;W�8�@�~�2��.����\�v�(�B�ێU,�&�2?�;��+Gc��F�垛#��H��J���	�˕��-ajBc�H�N(e^qt�v��(Y��9�P%�����Ʈٗo���f�@��]��v�?��9��'�t`T�]�����(���b�>�r��?� �����gŻy��-�8!�&)�1����x���1"
�[�2Y�E(�:��ލ�Z��g'щ-ׯ6Fn�"�����T��*�|�!������Պ&fn�p���"�����P��NR:������4��_��F��������Iƨr��ԇ��|�px��P����J@⤮�Q	�����U	��T.C�%4[Xs��,kjR�|�C�
�cϐ4�c�by���JEBD��W0�r�ԯ�\��f��o�%�"B1ǲ�vy�����w��X
��Ǧ�d�^;�Ȧ���rv*_�(���ߛd2��b폗5ۊ����_�c�FB �H�*�s;=s�S��p8S�|��&�q8p�/WM���b�1	��]��߂�ѱ����Ĩ��+�~;�Q��o��&W\5g�OU�!�����u�I5/��P�͋85h̚O&6^<��xQr�*(�+ѱ�z����E#��X��:\͓r�c�E��,Y�Ȱ1Z��Ԛ�c 1�����d<�qo*�����,�f�R�A��x'��T�9=��SQn��{Թ1�9j�iƶ���z5'G	0勪�-*2 ��J4�k��6F-S�z�xPdu�Pw�FƗ�c��|�.�~��j�Jm���F�؊��1M`�\.�2a�ۃ��TR�2a-J1s>�%LX�υz�ba��@�K���D�~P���C"�Ԅ�[9\F�c��%�2��%�:X�W�D(JM�A�d����cA�Z�\�T�͢u�Mͳ`�G��6��t�wV�V*b%� BͺKm+ԍ�X�P�[ �Xc��ގU�IdaIvL=�]�±,�c���O��H�[��hB�ec�8�J��`�Ε��VP���q+�Rњ�1��@��*֭`���Wǭ��98n�8�d'H�ʎW�l\s?*����(�<�8X�9�+9IX�k֯�Fq}�h��{0FT.;�ѯ�Z}���P�ls�@�J��'+��Nǚ"���0o�I+�ez�ˠբ���߈\��L���7a7�j�o��;��jc/X��V�f�Z.�<�Xw.���F�$4S�P�`����+�������۷\�<Sa�+�uΌ�K��%�Pu:�LJ&+�w�������\l��ԥ1�H�H�Jea�w����$̰�Bѱ6��wD���5;NT.J�� �  �>������T �+�$X�	Z�S�̡�����Ǜ��@S����m?��fv�PG�@��j-V�03绖��e1� -c�5#$}^��	MA���rk��â�s)�����M�bZ'0}N�>���&G�1��>kCN\��� ҍ-^�1ш
�Ѥ���X�nLC� +�3&�o�A/��ٹ��`a�s��ub����(���<�4W_�ԃ��5昱�1Û�[,����X�2v|����y��[�"�b��%b�o��yŜ�j4옉y�Z��A�9<�r1�!��GEe����X���秛���G�,���Z^Ѯ����q��zGS���'���j�� #�:X��~|T�Ǩ�/+���%;��^��<��`$�4�_���������	߈��@�L�ov�"3Z9m��}�_v.a}Y�T�OK�X�	.���"ӄ%S�9B ��$FL�_�ƝR2m��w�i�`
G-�Ŋaq�0�;Kav�DL��q����? iDk��ߔB��?L�Q1X��6(�`�B�Y�c�w8�?@�acS�!Ė���q.��#�c��!	&���e�C��E����n�l�OC��{q\"�L`ױ%2�Nab]��j�"�]6�m1+�V=�@�a����O�e���N�S�7R�Q�AT��Q���M�Q�@� x[ ��0�Ow��c�0)l��A�&� �KW��w��S�D��������R���'�LC_Lmj;��A1�{JF�"*Yoa��b�=j��i�
J��D�5�����V֘ߌH��Ds$�ka.���7�na.�d\�]ǚ�+8���}gDM�mdߒ�hR�X�.݁���!4����?v��X�2@��_:rP�����9X ���+FK��0����� �9���s��߫A�c5'OUVZr�*�&Ǟ�)���Q���
eD��<u���KD�ق��.�'��騕���������&�
�:`LQ������Q���íf���M�J�#f�������ePO	�z�Jm��N&�.<�3GQ@IO�[���k����R��C��:���D�0d.��<�p@��4v�B�b͉�"fVu�v��ꅟ�U�����運�K�N` �̎���g���x�p�]H'n¹���չ8��m�0O��z4љBs�m����9̈́T1"'2`�s������9ݦc�	�'s��'a���Qt	�@��7(�xml�$%�8!i���:c�.�Rm߇����gTJ����Ũ�i2���C���s�l�GX�	�`}S��ӻ�5�E�;�W%�:`C�D��ND����;��0��S�U. ��s�f""���i�=(pN6�� N���o�.�=Ц�@��F''" Mhb�.Z�%�Y�0��;��xi5�(N��9!��8�S����"�뜖v�z�أ����I�+J�P��dD�z6:�@�Z����y��*��p��}М[i��jBx.+;�j!�a����gP�dr��/JW�l�V�V�B���2o�	%cL�4c�[I�K��IG=&��9�u�&�,iO�*�a�-�a=��������ڬ��%d~�"�{�H1�,P_&�F�X��1j�0���`i~$ �$�"���
ݩك���Ťg,Y�ޠ!�T��	���KL�ŤL5��%����L-Xm�lAeW��w#��̡:Xz�X�|�j�N �3R�s,X5�&˘ڨ�{�Z�`Չq0�dL�t �W�9m=��*9��PX����>���rt*�q*��$������`e�4��:�������@�a��98w�#=�_N����pt�A6c?��e�20���V�@C"Һ��.9��e�>�.�$�{�V����h����#�t�4Gn�Kw־-�w�^
��b���%Z,�r?�N�QA�hՉ�@�����7PDښc�Q^,;X��7&�1�L��#*���e�Ұ�Rf)�Q5��D r2%�X��79�4�Z���ЃΕ'g���P�s��'�n����|u
��D��Y�.�I�@�9%�
*���85������*A̚�m�/�h4\-��S�?#I�F$����Ui�x �s�ӀDvJN!=�Y�!u9�e���`@N�����2:���f�S��fE��83̴9jɱ��s��8Ê���m|�L�y��ZfZu���Ass���mko �(�	u@1:ҡ,��ir��v�/�Tر��Jzq�P�Q�cA/UͩwT[�IS3b���.��lD'
 YD�N�A5��E7��@s�
(���4P��{�r�;UpJF�̏ɾy�����n��F��S�ct���Y[��ZΛ��Փh!�z�;]6H��	�R���U�u��d)h��bo?��>���� 5�Y!����x��C�A���
��Ϗ�r}(HȭĊ�~K#��֧/�7W9��a���x,Q��k�@en�.����U��U@�8�7Y�S�.���R�`qy�K�^U:n|��u��D�G���]%�L�26���m�f� 6��\���~D5{ĻFZ�k� �%�����Q�"&W<#���Ɉ�І��1�:15`v�qޚ�k[2
�H��e����+��q� �,�㕤w@q~5�[���)s5����!sC�����0ѹm#��hBլ$x�I��(��@�����2�_�@4]�s�4��.�D�z��q��\���<z�d-7]r���2,�����Ӂ*�cO����=�I/�O9@3бeM��A���8�锣f�o�/
��mC��6��5t�d�X:��(I��L&ȏR��=<�<� ��������[⮝8�ͳ��!�E|�Q���-A��@�����ջ�׋��p�����8g����ޗ�y*��9g���!.D�ǇgDhCU�c^�M
�+�g����'������>]w�� Į�X�3o_מe���|�az�����Ӽ�B      Y   
   x���          �   
   x���          X   �   x��н
�0��Wq���pp
�!�Vm�:Jh�tH[Ҩ��M���v<��~��J`�<���f�n�uF׮��VFc�JN];�y\\��r�3* Dg�S�a�!�8ǀ<�P���49I/�'����jY���7�G۔��UM�B�6(�;�>_��}m�U�=���Ә������      V     x����J�@��y����ă�P�l+�X�%4�LZ�U�[T��@Tz����u:�`��� �����of�Q��"���"3�Ib�qa3��rb�LL9-ҹMg���I�(���--�����l��c�P�(�[�^ �^�L�	S�a�ԶBW���?>t��{E����RiC5}Қ*z�ʹ�x�-�ӊv.FixM��߁��v��*���-f9�O�;�-��3]�Y��NB��%��U*p��kMQ�|�5��F9�}Y�)ө��;�������C�;b��W3n      b   �  x���Mo�  �{~7Z	U����i��LZ�^#j�ːLִ�>pSGdI�I=Y>c$~��bg�Z/~l�r��ʶ�����T-�\���\"��LH�(�0��nԓ�|�>�X��i�t�,7bo�kk���{�h&Y�n+r��"
W6\�]���l��K;�v,�yQv>^��E�~Q���h�3{��V+-�P�v�d��5�
B04B ��m0	!dnC��c`k�yu�e~	�������S����rTdIG֋%N,<+o�6�1����c�#���Rc
��>��W��A��I�=��2�N=��t�tD4�{�.	�'��CJdzޓ����������nr�sŵ���!FG�E�Id]��pùF�wh��[["�X�b_9+`q��5�"�~:s)�ҙ!��)��/��Cʔ�����m ��E[�%۠h#�۠h;n�]n&�A�F��5�m���fڽb�m�N���ĵ�����l����      Q   �  x����N�@��<�ު	1��'�b�� z%�jm�|
�h��\��B�:nwW(~ܘM�=��ߙ��l#h՛m���(Ōo������ڐ�N�Q�&*8Oh�ʈ���D�{�I��60�eD��9�E� =�� 8����Rc�(�
[A��D<�sRq�@��mM�C��:���hi�5�����\M
�~N�O�Pz�~c1�"S(M��*��C�D�"��-
)������L�G����) \�t��:�H}q�E;��L��n�:^?�b����عª�u�^j]>�S�QVH�
�3��.L �V@xU�Mxئak~���C�����������2̤��OüW�h����I���j��vv��J��V�Gl5�rI����`��}�il�*Ytd�x��gF�D��7�]�?�U���2�md�53-I�����Vx�Ȓ���A�#�3��?:�8�}7�p��k U�<c,<i���ߦZ*}��W      c   �  x����O�0 �;Eo�d��cc�'$� ��<F�&î�����k�+�,��[���ҷ���4�����>�t���F�j�ʉ�ɕ:D˙��(����S��*-���	��!)$1�F�9�M��a�dﱝO1�0�|.��U>bs7���rX!+L���+�F0�8GCn��D�M�I���kt�U����!���hs�Ř�����hp�Ik
,Ew[�\��jmG� �XM�Az�l_�V� �b��}�`�`�{�^������k�:�E�pk�_B�w��þ���2<G�;V|�R��y{n۟̏�X��sn��|�_���K�����X��X��z�Ӆ�sƏ���U�V0VY�*\���"׿	��H�y�M'NB��7���Ϟ^��"/�K��1	p�/`�8+r��O]<K�_H�Y�Zy7"Z��	 !      R   G  x�ŕ�N�@E�|��Ik�R0ƕM�b,�4�Nl�u�j�5ƍ����wd,����doV'w���� ]M�&c�3,O��E��*gt���[�Fb�3̱�%/*��.\_��Q��`}��o�H��"�b�,�.��^�i[L}�{����;gtp�6��Hb��%�u-�Ya,ť�BI���G��1i�wfH�4�5$��׋�N���?V �A�.�B-9�hvH4!���i�:�,�K�F�w���ԧZ�z\�7����}t,���J}�����:{�K�f��C����g�=��a���UH��V9ܷ�[�o�f��      �     x��U�o�0~篸Y��5<�+-h��$D�Aۇ��\r��P�aC��}�$�a�~�v��Pr�ﾻ��]���?��^�l9C�����q��@]F��!1�rAw�2"�����!��:�F������-+�@fP�J6����<$��}[��%�jڀ���� �G���GLТGp:�xo8���ʡ40��۸z�9~C�jMױH�\�X�ټOe�*b�I�3�Z�+6�%kr6��D�	ʐc:G-l��(Z!m.D�9�21[߹|^���n��G�tV6�����A; �QUP/΄� / �w@h-���w�8���^t���5Nj�}�˻ü��V��&�S��jP����=�Ec1�_6r��SZ?��J(I`���!e�dk^�ߢ��
K���o�uN+@d���X��7��] ��A���Q¿�nI�WW�L[�s:ۊ�7hó�����i��U���tR�xm��4��Nm"\6�^?��}�#��M�Os������a.Y��Lӧ���g�g��y�hfk��-M0�      �   �  x��Ko7���{s�g�᫧R�@���j���6߾C嬤���nd am��]�y�gH���~�..?������/�͞o��ۛo��~v7�t������*}�Ǯ���y��`��q����<�_N����b�==��G&����b~�m��ߟ拇�k9v��?7��p���n�.5{||z�g���>\ϖ7�rߛ�������_>|�ނQ�������٤C��0� &�嗏y8��<|�
¹��@EL��'�g;�u
`Ԗ�-�������`»��\�
���fH�S�a?IC;IZUI��2�0�$��)uD?�J��sv���O:r��b�!�#Lҟ��QS�)*�u���H��T��\�����8����� �>�|��2S�!�?�j�#�G�d�5�H�G�$�WA��S��i��i\�z� um�M�~ݳ�� 3�a73S3/���&3d��xm7�<��E�#�E�GH2�^��_����8��96	��d)os^����?Et�P�C�S�w�>x�����Gh_�*�ZR���g����E�t��"H_����p\	�q~jt.�ܹ�N�ht$��k�YmW6:#���U�X|Vi�
+~��~�=��V���
���66@LGcZ!�X�;�Ƹ�4�i�b���L�pLK"�
-�D��B�:�� �
h�Ƥ��x��`^��ш�0"-����x�.�E�ir�IQ%.i�d�8ºV�r�m�\t@�\�&5O�J���4b��}#Ĩ�
�a�DE?E��̚B~3DThu,1�)�J�o���}��K�<n##�|��I�צGlO$�TX��b�5O,G�R�[=1)��Gl(�%\6�V☕	�������d=�1ɕfd���FE��x�b�N�c�D�[!&-����W�f�IעT��y%fu�K'(�4Aɡ�5�ǜ(X:A�&b6�Vd�D��)
���H�ؘL��68�+}Q-�O#5�bZ�Ǽh~���T�^:�N#XĶBL"���Z�,PA!�11�IAu�$�Y�Z�Be<1��c��f%@V��,H �����5fe`������O]�ʠI,��34�h�0����Ql���gh����Yt��Ȳ�U[wNi��-�%�5X3�aX�c���v0�,����̌�c&]����f�4���9��7��a���L�WS2 �3������9�%6��ӗ$is�7������pIl��~�,��\���B�Ն7;j�m\,���uQ�"1�
���~�K�s���JU��ބ�%�4dm�1P��ٴ�:�����c�>jR���v{mCCΙA��lp��v���h-L0�R4e�N�l��4Rی��F��+�9	8A��X�V�u�b��[ZV{��jz����Ǧ�0a����A��S#�芈���ldG?�@�%�;*������-�L��+�|����4k�OtH�t��]�cY��\5���������V�4]7u��V�� �S/��͛��       �   �   x���v
Q���Wȭ�M-�KK,�)�/.I,)-V��L�Q�K�M�Q(IL/�Q(�/�/�, ��K2ˀtZfQq��Bqj^JbRN��B��O�k������:�Gu�P���@ђ��T���S��i��I;7!��J�Q9�&.. ��`�      �   w   x���v
Q���Wȭ�M-�KK,�)�/.I,)-�/Q�@�g��(�$楃)���E�%��y�
a�>���
�:
F:
ꎘ@]Ӛ˓���:#� Z�gLO���iH��4��=.. �8�c      �   �  x���?kQ�ޟ�:�`B�����T.\����AD�-���E�},%iBJ���c�������v~sw?�n�?�?�W�7������~���g���ۇ��j�����~�m{9|�~��f>\��j����e�\�7��������4�	�f�����+x8�
�0<p\r2zn�oA� 
⡢���~zn������qF�8�z<eT���OH������qA�,��ҝ@�S�O-ȧ����p�	�NB����zQT�@}@A}@A}@���_�_��0"F��
�
�&t~'t~���a~w��Tn*)[���:�#��qw\�E�ȢTdQ*:��*O�y�UH���,�0��]ELT$�Ui%�����l`EorE/FU���+��+��G��(�Q�jNjP="�3""F�z�~��[,����d�(�	5�5�����P�
~�Am�Im�Qm$�G`sǨ�5�5�<rl�U%U��P��q��P���l���TC�!�ҐOi(�h(�h(�hȣ4��2k���Yˆ�eCƲ�p��p��p�#�֑o�ȶw�;�:j:�g�dG:ّ�u�g�zGu32&5D5D�^?~�����zB����F�pR�P-���kR�pRnRnB�9��<�7�7�@4�@4�@Tm<�Zy��L�%�P[����Q{��	CmT�Z���j9/BU�P3����8;�u���      �   �  x���Ok\W���o���$�?zd�@�B�tL�@��d�6߾s%Cw:����w|f<W?���ܽ}������/���Ǉ�/~������������Ǉ����i;�����}����i��x�����ÿ�u���۫��o�nϮ�nקM�~����ޞ�������o?.�S�_^��[��o,��
�;K~���ɒ��o@�9�������?�=�W��<�<�+h�|ʺ����~ ��R_�أ��׸� =ʺ�*�R�/�:Dz��R�+o"��R�@]Yꋺ�@�]�����~�{ܺ�Y�Nd��]���ց�]X�N�}���.���VX����: ��z���iY=Nm: ��h���;����]W�w�yeջ�z�uʪw]���U��X��zרw�:eջ�z�uʪw]�> �V�k��uʚiuM��NYS�-��:c��m`��hc�6��H����GMc��.3jҮC$���׬3�<o�g�:c9h��b֬3Vva�]̚u��.,\�Yg,i�]̚u��.,҃Y��X�Er2k�+9��І�a-\��e�H=�X���:`��ZxX�cyX�u,k�a���aM��NX���:���A;��A[8h�a9h�6,m�@����m�8Vnc���:��p�`�A[�`+=���`˿[��������p�źH@ZVz`����������]c��;({͛���-wP�8�e�[��5q�E��A��o,#�re�����l�A���"�0Ҳ��i,'��I�^c���t+-{=�5��n�fE �Xv����cy�nZP�e�[�i@=��n�E@ݳuK+���-<��.���XB���Y[(=>/���Y����^g[=�-���Y�V�aKk�uְ�s�Қz�5l�7��^g�=g=���Y�^�YOk�u֬�s�Қz�5l��P�5luMy@=V�4��ZSo��?��VSo��?��VSo��?��VSo��?��VSo��?��VSo��?��VSo��?����^�������K^M��*�����z����W,�O�Ջ���'��Ό���d�3�=�7��~�y��¹���g၍sg�g�+��j9��vΝUx�,�;��y2l�;����k��'v�޹����x�<�Ĩ	6ϝ5jzZL�z�,��)��sgEʞ�2X>wV��)��sgEʞ�2X?wV��)��s�E����YJ����� C"�u      �   �   x��ӽ
�0��=OqcAzi>NR�V�Rl��U�:��ML���$Ï�suS�Zpu{�i������s7/���3dw?po������e8Wd���)9�|�*dB%�LB5!j5�m\j��ڤNKm�N,Q�R("5K���ZZR���r��h�\'%W4�c_��\�      �   |  x�ŝ�n�H��y��%Ydb��Ẻ��D���(�1� Zj��H�����-�2�}�}��Β�n'ٜT�qE?����UWu�x��+1�����tP��mx���OG�g.��6��>�w�����GI�V��MnG�x#�	z'^���~���%1� ����C �<?�׿�����_�S��������,�#Y?pϜ�G1��I��u.T�{��^}V���-q�s���pLb�gٝ�u�Q��4�߫Cv��rZ�T��8Zgb�E���6H�O*�Fd��$��J�}mv��5$�5JǗP�/�Qb��&cVg��6ZG�EV˸jJ�z�EYV���I�$�[�$tŒ�K"V,��z��>�8&�0��'�!#ܐɖ�lE[{"����X������	����~Cj���d��y�p���k f����$\�c����"���^��徿W���X�B2�E�Q���9R�{��n�=�~��9�ml����r��E��}�Ru�֋M��j���Su ���U�q-�]^��ư�`W`���<n5n2n]� I��D�
gx]~�e�5r�9�&6b����#�G�QX�g"N
5p����j�q\ߋ�a�~WbB���K�`�C�%�c��}�X�B�;�9�D:����cd�~�Eʨ��Z���G�`��xg��Y�E�PF
Y�c��h�n9�}�|���f��luqX����� �� ��H�ٳ�L��p��]�bO����`��q��5q�Y$�Y�,=�N<�F̯E�q�dx*�9 XR��Z�	�`~�C[ށ���op���ZQG,��7,o%���j4�<����(��e�2Nu�Tg��X�ʟbq/��ӱ,�)$�)$�)j��+�M�#��t|��~����U���
�-�s5�?q�t4�z��+��ܖŧ+#6��7���1\�(oqH? Nݑ�<D�\m����g�>����g�:'$nNئ��'�빇��A�k8k�L�я����7�I??�o�&jW���$e��s �"�5l��\���a>f�c�Nm�ŵ�ǦX��Q�]��psyO��$$В�I�i�*.^.��O��LE�p"A��vԩ�dO�azyERq$�C Nse�o��LL��ʻ�|l5u�AH���r	>�O��h��(!@M1�]�ܭB�49�T���o5����ئ��O�V%^_�绍ϐ�흫���>{��"�ҷ,`z	�k�i@�*��`@B��d���L��;OU�$�G@��i��7�NG���BI�0(��Zvvʯ�ϨǪ�)/��X]~+��ʗ�J�V��I��F�/2�N�{Q8�ᚣ�^,Suw���x��$Q B��2�`5�����!�ċh�,�7���j\>oj5y{v1C�F"
�M��������5"/�od��{��Lz߈Ը9ฆ���v6-�\#�R	N�:Zf�,_�ﯲ�491覎�8 A��֤����m!���F���)_�I`��A�7���m�z1]�|��a9m<��'�Z�Ѥ����/P<�E�&!@Mk���������㨜<4	���4��ق�<���YYLYb���m>�� 7��oB1H��0$�Ǎ��t�s��瘛՜k��Ar��[�EpFU����O�5�F�$�F0Z߰d��4엪����נ�����\�m5�8����!���u[��Z�Y(��?+�`�} 1�B�\���4�"���U|ʯ�쁣��ru
K%8Uv���Q�x]T��?���\z���K�σ��cl#Z��o��RF���! �������|_M,_��7*����\%��_�<a�r����c�7�嬓��.`�J"�n$�04��\#��z��52h� B��N�]1�%��0>m�u~J9$U��
q�p8�tU�8�mO��E�0C#M�Zzoì��J3Q)L2ulkHV[��RY.�<d��ڢ4����6�R�Go:�y�6=I�H!5-��R�I��#1b���H�I|��F�Z7:�y3O+��ဥ���A@sb��by��c�I0��<׈G�[��FH�`�eu��m����'���Z���t8U7���H� ��z?HU�a<���R�"�����%"��D��X��aI �@��R������{��Үw�Q,����C�-���{�e�:��V6-�a0���~��w��}�j��8�2�P��QYx�# ����JfsR"̲'�Ъ����L���dX�u5��y}�;V#ZGN �c���
�j���mN�n�*E��x*���8L���(�D���]��Pq��� %IX$�mpp���0U����F�`�E����R}�ʄ����'����K4����r�s���i��6{31B��\S��]����3Gf��d#���� =k���A1�P�7��!0B�����Uj���sF�&�0B���\��R�X��є%q( �i@ V�7��<��7�>0mIӒ@&�����y�Uy������nO�X`h�ٶ��`9�q�1��~�bf47����J}��jF���$���˱���Bx�b�-��#1b�8�5)u����h�74����c�Ѵo�"�5�~s�k�#����xd� �ʟ3a$C�Km�?�ā�F�&�4�Ѥ�aH�t�,+/��yhJ#��lݚ��1�Dd6n���:�8Ǉ�"<$	#���m^�t����n ��1�љy;�c�fDr�F�~}��"ܔ�v�u�wW,b����Əu�S��pXu��&���8�hY�¯:6ܫm^ΖLD�%wuʇ�,_�L/B����}Ȫ�H�B~AH$[5X��vix8�e�|M���# �6�����<��7�[/��qU%ĵ;\/��b��,]ќ���x�h��U�ҕ(������ �@7j      �   '  x���=O�0�=�ⶴ���]P'��� іE%T�1��{|f�m�%g����h����@Mwx��6���x��G?��7E�?ϊ.���������4���pM�hM/��q��U��9Պ���ض��S~O�＼N)��m��<mu�އe/��f.��k�5���f"�J+h���8W%
��g��Gs���a�s���RB�y<ǩ����T�%37BO�s�p��ݡ9�7y�(�0��=n+Qjb�W�.�"�G�Wz���hϱ'd'GўeOl�'uN�{��KsH�fVUt��      �   �   x���v
Q���Wȭ�M-�Kˬ�OL.Q� 12St����<033ES!��'�5XA��RG��XG�XӚ˓"S,tL(7�PG��2S!n1�� 6��P�ZPd��)�G���t���ƀ�dhHYȘ]c4ƈ2cL�ƀ�/ �D�      �   �  x����n�@��<�ޒHQ�Y�1�	�PӤ�i�U�
�I��C��1��&U/4��Yg��X��� e�7���gg�{uz'�{tr,.�_��������ߠ�/>}���-�g�ӯ�/W�ϗ{�]��m'�޾��ΰ>保��Z����!RB����tM1-(A��Ӕ�iL��̔��j~��>��F��R6���-�f�����3��?�[^��oL�5�����-X�_(~`����/���"S�դ%o̬�KX�;�F��!���OY�DD/z�7 4cЗ��
���ף��AoX���C��rd�9P8M ���m���7��,0b��	���s��ҝ���6zˉN-Z�ȳұg�S�J��m�ג�
�o���OA#�Lh��f�>���ϳ�g�����G��i�+���_�B*���KO����ԍ9:>|�����H�H�5�g���S��#�6����j닀���)�V�uc&�FC+�tT�������NAdV�,���n�q�|h%���k�LRU��,�P��7_e��J��7��#��mr�����W���J13r�����s������z�
�|P㰷�!�p��<���Q:���� �
��nV<{?�2DP��R���⟔\�=��2�      �      x�ݝ�nG����)xǽ1v!χ�+R<J<H$u�1�{�h��m����~2s�WDep��/�-t��~Ϊ�/�ʊ<��>���9������~��:����_�~��/����/_~�����n�������󟷟��~���G|��i��?���˗?o�~�a���Ͽ����?�燝������ϝw{go�w�Û��ή5:x��Îζ�O�t�Q�M�Qq�ava�6[��R�o]�=;�������3��P�����T�)F*Q
���J�ϳ�S�[;2Q���ҕ#�q��g�g�'���yd��*���6�1��Qa6zvq
ɘ�0�
�/]��ZrU�٧2 Sv^���Ӯ����"7
M�R*?��/�j�u�A���s�O�Lc#����[\�J)�u$�h3[;�<%��s���ˏ~����O�~G���Sr٤40�ͺ�Ս��۟4��R�U�l��ݤLֱ;,����w}h������)#R�^h�۩�Ŕ��彌�~4>fƧ �GHtRCD*������Cƣ�O�4+39o
��\A������}�Xgi#��5Q�X^/��٪٘I�2���M�bb��_��>�SA\���#����^_^�{�	(0�]^�.��Ĭ��ܼ�Լ�.�w�/��~������o~���G����:�/G�����񲪮ʒ���w��;9<<���J�R�n�їB:0�ɱ�����8����V�bMÁ���uQ��_zSZ1�4�`�vCsD��yo��v�0�����u�)��F.4���u"*_����
CqjUj.S�Q)���۲�(����D�*�e�v�w�g�����
�fxf��ó[�g��x����e�H���A�Ie��Y��?��ͷ�eR��q[
��Xw�ec�f�
�cx~��<�ۄ^�&����6�%���	/sgQ[�g�l���p)�ۣ-��[�ަ�n���m�톫�ަ�n���m��ˋަ�n���m���٪����lS}�t~9�gJ�>��V���� xtz9�gJ�xtv9�gJ�xtr9��.�xtn9��.�x�.�N��"]��cD<�0:��.xx)��ܳ��==yc��{z�]�P�뻓~|�7L*��݉����������o��l�U;��Z��L.i���W��غ�<�9��s�\won�~S�EPc\�~�=��}�%�����_�Q��6HS֥b�sV%.�z{lل���믿��.n>U�]'���[��Hq�鱗p#U����SYD>n��T�/s�鱗�|����,"��~*��ǭ���"�qm�|�*��,"��R*k���I���w������T�-��hu?�bK4<�hq?�bK<<Z�O�����S)��ã��T�-��ha?��><<Z�OŸ��&,�b�Ƿ�-B�����E�]����H�{��T�]����H��)w����"�.x|\_����������q�r8>���\�]\��J)l+��G/�si7�:ϥX	����+��Q�>�b%0<o�ytBOx;�)6݆Ʀ�%�����_��]����L�8t���W���]�)L�m��~�9%=�v����M��T�g'�t�#�qm��޵uw�Ȏ�U��T7療��Qc�T�?:(�R���cC1%����<9:>	!� w��Z�����o��:�=�����}���t��Kc�W�.����F������uNC�������%��1��1�`������M�����&];�2Q���Iw�a�Ղytvy}ݦ��x@B�ϘlCz��yy�?��┥yӑ�^RnR!oflG�ml&�%��_�i�ħt��o$einv$-���iz��rg��\3��|�h�w$-`�����l�HZ�B������Q�a�S�Z��{Z+KC�#i5N�FDG��(8�ڊ�����h��CfB[���R�&�S�Sp�К���𮽫����h�BPZ=4��Me�Ci���o�.�,��Te�g�֜��Z�?I;���G��#i�}�$��s�����g�na��-K�B��%�~!4:���n!4:���^!4:n��N!(��$���i�L�f�h�1wP���II���=v~����f��~kT{��g���T�u�5�ﲵo���m�p�񵊴��,t�&��\ht\'��\ht�'�m\`t����������N�n�/�VO�v��>�_�����R����X3ݗR���Go��R��Gs/�����^J�1]ν��=<<��{)�{xxt��RJ����bᥘ���-h�6y��R����,)�����"e}x|\]������%��qy��$<>n/R�����E
�����H��)T��cϘ_��R��N�u7�� x���c%8<Z�_��-��X	���Wb��GK�+1V�ã���+�����J����h]%�Jpx4�x%�Jh|�I�+9V����"�Jp|\\�X	����+a�Ys����������H�D�-�ݻ>��-�,�c����u�R����9܊Àsܕ��v���2@9Ve�Ԡs���E�X��O:�j�p��9Z������X���2ŵ��'���#:Jۓs�}q��y��,K�]�嶿w�ߊ}����������=z:;�F����?�P@��I�j:�ڏ�î���ښ~�8?+3�l��H�e��뮐�I�l��-�ڑ�7��7���5�@�l���q���3���:ϔ}}�����l���?���d;��S����l�k��jʓ���]3̷W��|���	Lh�^y���v~����ዟV}j���z]��ڧ&f�о���>⹯1r�O勱ܽ��f�&��И�:���u�6��H��r��bS�<�G>G��֥�|���b��Ԥ�C׾!9l�ߕ]fպ���?������Ł8?��s�9-��Sk8����h�'�hh�	im��o��ZsϻO~vaJ�T�5%���y������|�oo��c�N��{���n�����,m�����l��hl������]N�'ڬ�\��x��a�1�n{��2 �_�2[B֨�"R�SW..�n�_�����6���/��MR&<O'����	/+����]o� 5�*���>����8���|���S�n���b��u�>���c��4<6�z쿌�����"�&l�����e��tcs��=�Yȓ�>����� ��8O'�ão��]����>�b_8<��ϱ����s,6ćão��=���}��X�Z�G��9������{����p|ڲM������������������������=������������-���"��I6��M6��Q6��U6�f��+�+؛�%��pp|������w������#bW84>�N��������w&���Lƥ6;K�l <Z�ΤX���ϤX��3)��ã��L����hi?�by<<Z�ϤX��3)���c��3)��ã��31���[Жm��l?cy<>..R,����E�����Z��^&�u��zv�j({�Kep�t�6q�4o�k��5���1�9�����Mn��K�+�{)v���v/Ůp|�����y��
�.}�V��\�6y�*��9�_�H2�`>�X�2d<>:���AO��JiC�����t.9�,<�-}頿�f/x��奃�F_� ��̬ad���\��,����|F��6o4P���h����_).7�����K�^�/H�����x�vd��h&�[��[�h�+$X�C��r��e6���mR���xv�Cѷ�[�<�g���d*�.�@K��@�m|e�7τf�o�Nwi?�
ج�l�j+���,�����2��}�`�L޼�e=Ms�j�L��ä�{���5�"|�b���ͤ˟�n��8LȫJ_��!c�Qb�Q�N#�X�:)�/�$���7F]`�y_~��������B�#�툒�_���J����%�Ʋ���.*�0t`�6������?ˊ���u�B�B�Q�$Q����~-��y6zVn�F�w�@b3;lt���3�Z��L��v��?�����G�����>9���x���~?Aģ���)"M���I ;kt���#���l��-�xxu��V��Ma@�M���    �ˋ�2ԫ���#jӖT�v ��f(kM�������{��mcuz����~�K��N�9��wNmL]"8c�bm������n�Y���W�7F9�}v8��ir��Z�B���ۤU�C�\~��o>̬�ھ���oa��M�j����t�{���R�����u�{\��b������ڼ/�qE��˝�WD>�/�=��|�_��B�������eZD?3vr���6k=s��|��O^h��m�+��nˉG�+� ��}��Ɩ+́�g�픇{�;�nay���c����4�s����cU�O6�k[̾|m�3�/P�6��Xm z�����E�UQ)ʢ��v/��%a�ֺ�N���*ֳ腸��.�^��K��hb�B�\���z�7���Ѽ���u/��%Xxn�m���=�F�on��U� [�]{�}}v�
����u�_s��6j$�QHf��^��Ȱ&��Gc��8<�����+�oa��M+�y酼+��/Q�]!p||�"�
A�c��^ȻB���*E��Ǘ)�8>n/�8>�/�8>�/�8>�/�8��]!۳)$�^hR���z�H2-�R���Gk�� ����~ �xx��H2-�R���G���+���X�@����x]�b0>�/�R���+������.�.x|��K�/�R��ǫ������.�.x|��K��%���O����x�V�G�߹x��~��qnp|����ǹ����w.��G�߹|��~��qnp|�����U������|\�a��s��*8>n/�qUp|\_�������'<��qOx�������6��NQ�d6[]�G��E��-"������x��_���iZ�/�m�hi����ã��B:<��)V�ãu�B����h,q!�Jx|ڲMޢ��H�)V����"�Jp|���+��qw�b%<>./R�����E������H��)V����"�Jx|��_vb%���)+��E�� x��_vb%L<K��e'Vţ���+����~ى�@�hi���J�x��_vb%P<Z�/;�(�뗝X	����X	�oA[��[,��N���縸tb%P>n.�X	���K'V���҉�@���tb%P>n/�X	���K'V���҉�@���tb%L>v��k)V�j�Ik�m���Q����Z����hu-�Jxx����b%<<Z�_K�-���X	�V��R���G�k)V�ãu��+���X�+���_���)V����"�Jx|�\�X	����+��qw�b%<>./R�����E������H��)V��c�Ӽc%<>Z��H����:�����G��)V�ã���+�����F����hm#�Jxx����b%<<Z��H�-�o�X	����F����h,�F�����e�����F������H�7)V����"�Jx|�]�X	��ˋ+��q{�b%8>vd�1V����"�Jx|�_�X	����+)V�fRƇ`6» ���+)V�ã��J����hq��b%<<Zۯ�X	���+)VBó���+����~%�Jxx��_I��%��X	�oA[��[,;��J������H�7)V����"�Jx|�]�X	�����c%<>n/R�����E������H��)V����Z����l�Y������Z����hu��b%<<Zܯ�X	�����b%<<Zگ�X	�V�k)V�ã��Z����h]��b%<<K\��߂�l���-R�����E������H�k�y-�Jx|�]�X	��ˋ+��q{�b%<>�/R�����E������H���7R��Ք��i���7���~#�Jpx���+����~#�Jxx���H�-�7R���G+��+����~#�Jxx���H��%n�X	�oA[��[�)V��c-=o�X	����+��qu�b%<>�.R�����E������H��)V����"�Jx|�_�X	����|׏�����i��������]?VBģ��]?VBģ��]?VBģ��]?VBģ��]?VBģ��]?VBģ��]?VBģu�]?VBģ��;!V�c-/�	�"��~����ť+!�qs��J�|\]��"w�~�����+!�q{��J�|\_��"��~���Z{�b%D>Z�ߊ�R,x1m��� ����b��G��[1V�ã���+�����V����hi+�Jpx���c%8<Z�ߊ��y�V����h,�V�����e��%soc%8>..b����E��������w1V����"�Jp|�^�X	�ϱƞo�X	����+��qc%8>Z��K��꠻��Fx������+�����^����hq/�Jxx����b%<<Z��K��z�^����ha/�Jxx����b%<<K�c%<�m�&o��[�X	����+��qs�b%<>�.R�����E����X[��b�����E������H��)V����"�Jx|��c%?i�Lެuԇ�hy� �Jpx��c%8<Z�?���{�A����hi� �Jpx��c%8<Z�?�����X	���X	�oA[��[,�1V����"�Jp|�\�X	��5�� �Jp|�]�X	��ˋ+��q{c%8>�/b����E�����������X)O&��7��8 -��X	�u��(�Jpx��c%8<Z�?��-��X	�V��b��G�G1V�ãu��+���X�+��-h�6y���"�Jh|���G9V����"�Jp|\]�X	����+��qyc%8>n/b����E���������1VB�c�/?I���S�A۰ާ�hy�$�Jxx���b%<<Z�?I��ퟤX	���OR���G+�')V�ã���+��Ѻ�I����h,�I����X��Ob���ǽE������H�7)V����"�Jx|�]�X	��ˋ+��q{�b%<>�/R�����E����Xk�Ob���G���^7w1y�y�>[��;~�{�9�׳H<��z��^�] �"��$^bx=s����'.�x�6�,x=o������@����H>�-�����K7w������] ���tsH>�.�����K7w������]�h��ʷM�B[_�u�6��}Y���_hs����v�4�4+?i�}����G��~'Vţ�}�+����߉�@�hm���J�x���wb%L<���-�(-���X	����N��Gc��^�ʷ�-��-�{K'V���҉�@���tb%P>�.�X	���K'V��}/+�6�m|Y��I_h��ʷM�B[_�u�6��}Y���_��n0�R��;*�FϮ�U*B�$�� �4�e�h��Q%F��0Z$hTĀ�A���	�/\����hԼ��4A���fhɦ���td{|$SaA0�Q#a0U�Q'a�0�
��E��B�lTKX�F��A�l�KX̶^�_H��S��mS�4 Z h�q��E�&Z"h�o��e�&��VM�-44M��BC3Mp-44K��BCs�d����td{|DS�" 46*$R��F�D���ب�H��N"E@hlTJ���Z���Q-�" 46�%R��F�D�����k�A?2�
��m�h�%��5.<�Lк��fA���&h]��C3�k[xh��ue���k�y��U-<�@KvW��ؘ�l��X�#���
I?�cs�H�U�~��F���Q)�G@xl�J���������~L�Ƕ^���D�)�`�x^��=?�WM�44M�)AC3Mp44K�%ACsM044O�!ACM�4�HЄ�-ђ-�ӑ��@}D�I�ب�H1	5)&Ac�J"�$hl�I����J����Q+�b46�%��2xl�K���z������}ԍ���]��5>�g{�� h�������p�9���-@4O�z��Z϶ �"A�� Z"h=�D���ZxhIђ�S-@6�#��#��H7d�Bҍ� ٨�t# @6�$���:I7d�Rҍ� ٨�t# @6�%��-S/�F@�l�K� �z�>�" �'�\�� �x 4G��BC�    M.4�@��BC�M�-4�D��BC�M�-,�H�K�&h�j��Z��Bcc:�5>�)Bc�B"E@hl�H���*���Q'�" 46*%RƦ��H�)Bc�^"E@hl�K��m�v��P����o�v2 Z h�q��E�&	Z"h�o��e�&�iOx"F@`h��I��f��Z`h��I���hɖT��������>"F@`lTH������Q%# ,6K�D���ب���1c�Z"F@`l�K���z�������~dfe'﵋�����Z׸��2A�
iPxڏ���4A���!h]��C��+[xh��u]���j�Z������td{|�Q�G@xlTH���Fҏ��ب��# <6�$���JI?�c�Vҏ��ب��# <6�%���zI?�c[��/�(M�o�d6@{��h���K1C�M.04C�$�C�M�-04G�$�C�M�-0�@�$�C�MR-0�DK��Z`lLG��G"�1c�B"F@`l�H���*���Q'# 06*%b�F�D���ب���1c�^"F@Xl���+)�M{�7�t�j 4C��BC�M.44G��BC�M�-4�@��BC�M�-4�D��BC�MP-04�v���1���G���
���Q#�" 46�$R��F�D���ب�H�)Bc�Z"E@XlIQ/�" 46�%R��vW��T�����Y�)������ �1��wA�y��S/H���z��^O� ���9$^fx=CĻo���gb�x���d���2H�m�&o��[��$�nh��ͥA�qu�G�|�]�$��n���g��t�$H>�/�0	���K7P�������z�Y�͏�L����ֳ��u�����qY���q�p}����[�����o��HfVy6qr٫�}p $�I�=����Qn�q�vr��VD��Lso������r�Y�˘��ɚr���[,g��xT-�3MT<j�˙&*˃�L�Q�<X�4Q�V,g��x�*�3MT<*������b���o�[���;..ˡ*7�������r����e9���\^�C1T>n/ˡ*ח�P����r(ʷ����R(aj��Ԥ���>���h 0�� -�`~l�V@��:؂����u�?K�`b
���L����TL��-8(�!z��@ɨzl�{$�K�	(��������RJJF�c)%#������Y��I���,�=�dDA�rP2� K	(q��l�l�R����L*>�u< WX��
�+�sIbŕֹ$�����\�Tq������L�K�sIB�eֹ$����\�LAq9R�%���±%Ƒ11́#�!�9P`�9�,
�H�� �ibb�F�Cr���w�91Ɓ#�!�8P`�<�
l�@��N���1m���d ��&X^��

̨u0ɨ���:�dTX`fL2*,0�&�[��
̯�IF�H���
����ָ�!�!�9XdD>�<���,2�b��EF�C�t�Ȉ���11��"#
"�:Xd�A�X��8���`��U�S)��j�:&���m����:��V``zLP+00�&��]�
̭�	^�����`�U���u0A���)ЂT��Q�����=�`��ȇ쀑���02�R�FF�C
v�Ȉ�H�1)�##
";`d�A�`��8��`������[�J������!���d���繿[��*T��t�ɳ7�WS)�V��q�Zp���U�ѓ:F=6Nx�������m�Ka���.?�R�pǱuNе�|�آ��.[�x�_l{���� M>��G�

�}�:8��6MQ%��'vp��-�b�я|@���qRǕ�-L�\j�[O��y\w�r�Ջ�Y7�4]`��%-��٧)����yxYcųp�Ɗ�x��l�a��Z�M�z�r���
�N&�炇W3V<^��~=����Z�-^�T�nZ��\���r�S�1�����s�����.F��.��u.sDH�;��s��Xg�� �ʃ�w�q���t���w�׳�������~nX��c%��$����e:)�h��
����\��)sI�>o��Ǭ��V����+M����=I���_n����v�SH%Φ��.��К��)4���Y�)Ks[���KJz䵬�m������z�ٖ�t���U���6+���Z�j��2�/��?���kv|��Z��e�����p��}	��p���	�p���	��p���	�1��g��x�ܣå�M�x�أ��-N�|ڲM�⹷,e�|\\�6=��n.K[�p���,m����
�����f(\>n/K[�p���,���|�_��G��qY�$��G����c+<?�0y�s�����7��:��x�.������xd.��w���Ҿx|.��g]���¾|..-�˧C���`b��(\�q٦␸����|\]�[D>�.��-"�������K��G����D���ǩ�Y�h/���w�-x��/P��G���9E�x��/W��im_<�����Ëp�he_<���ţ�p�h]_<������-h�6yK��ҍ% ���tc	H>n.���|Fqu��.�|�]��$��n������@�q}��'����ҍ� ���tc%H��/o�kc�_͛��	�E(���d��)��΍i/����>���Q��YVc�T3Y�KLY���88<:>9}���|�-՗x��t�N�r�i/�?f�߄��)�EǾ�K�N׶1�?��F�U��yT߶�:���N�Z�D�m�y�F���68/I6�c�!��T���H�C{�k�*ֽw�]Rn��g�*���'������sWn O���i��M;ٲ���H*�?�`��yb�*#7t+ӎA,3R�'-Sn��o����qy���{������ǔ��o�2N�6�P�%�]�k{�*��bU�Ca�����RFoh��x.��Ȑ�������{k;��Kbq1ġې����^��{E�<��-��eRD�f�>��m'�\`>�<�d���3X�m���*��ȴ��O��
��<t� ��S��H�f���='�]�X�Ic��홸<��P�i삟����n��b��'*��V���J�ӓ�����/۞_˞�"	Z�~�����w,֪�c�B|i:. ��B�u86�z����(�i{�>2e=����\d	)-��>�|%�Iy�a1F��P�v�9Y?�b�G%?tͷZv��$ʏ�M�����r��]_`���鉚���l�C�+�D��m�y�iM������R~l�)���tU@�v��mx�x�Ob�藘}|��IRΥL�Mb�v!�E�0��Io��G�}�򇣏�{��E 1�?���?�I�D籟��v���s�>I�~�,ޮo�85��B�=�,e~5&y��c��!!D;��z���2G
�������W�Nf�9�}Wh�^��B�Fd�����o�:.ɥ'%X5v�o̓je|��Rю= �K��r�'�q앣��I
�m��|T���-/�K���؉�o�ۼvN�L�7O��mm+�LLO�G���c����'�/m�"xd��C�X��8���Jܚu�R�{&5�E����S�>�rgMҚ턢��U�W��⶿��,Qv�����X����?u}Y7�&=�����W��~�A	��j6~�+�?�魾m�-5z�}��o;\Vט}�L*g����X��O�K6i��:��,Yx�~Q�~�����SӘ6c�.ᓺ3��d�\ac���՝/�-Q[;�S���e:O�KЃ/'���%�'n���-��_�.O�H)������fՓ#=��d�T�1�dw�QVmyD��8L�����ۡ�%��-7�Ǒgm��F[zkm���������(0��8&O�Yk�8|����)��Сq�s����Q#1�$��᝛�3!�=m�0"w��
D���������m�c_Zm�����ͧ֏zկ�E��\X����:\wPV�����I8fp�����j�������o    �8��      �      x�͝ˮ4�uf�~�&]
pso޲G=�����vO�jKF�/(�0��� �*��N���^��a���"2��A.�����_�����W�w���?��?��ߏ���7������o�ï~�������?�W~������?����?�������o���ۿ���~���/~�����~�����_}���������W�������ݷ���/����������ϣ��Ֆ���������W?���������oV�����"'�L�پ�z�rK�2Z�����O�����_���_��?����09&���01&L�����[Gki��S������}�	0�'�y�����ݏ���c� @�	Pk��+R0�������i'���S�c���9+-�l���^}�I��Ӝ�?���/-K���(�5��Mhh,1pډ��!����V�s������?q�/��~:���Ph~i�b��N�I�QcC�H�)K����c���F��@���d�q�V�����}� ʓ��{��-��$�8rT�ׅ0�{��R�X�y����������yy�<���9/O_��~�m�[�=�`��F� $`�|���<�)���a)���h�	��gt��3�|]{ ��|F�q+s��V�a�ψ��y7U��mv>����G�쏗� �LC��aYC����O���&�r���q+ȏ���������]����qΜIp20r� d`���!�ip�!��pJp��HpN�I�Ð�s�F�ðY�3��EV�+p�8�
\dΰY�3��EV+p��
\d���YA0� DV+��
���'�>��7KG�'?�a냮�au��O�1�z���0�)X��4'�]BSJP���ak����!�c����-kh:�\Cð�����a�@Ӹ@!��}����wkQ�u��Z�n���V���n%�`�ME���ŭē�� |���V��z��yFp~s+�V��΃p��[)OV��C��|�T{�t;��_�!hA>�Q�r*��~>���j��qf�����O��C�5��s)k�O����n�����O����Cp�<����y�R:y�,6~������y��:A<����~��`���?q��yz��|^�b<m?��e<?�s�{�'��_��?�sexy�i�u����P\��?p;_�\��?8�|J(����By���幐����Q�ٛ�~p�
� ���&� ��JE<?�5���K��<��d<?8��K}��W��x~p�tʳ���<?8o5�J�x~p��J}2_�:��}�"��-&�΍�"���ⱄ�~^��A��E �!D:���by�bk��g4�,|`uK�9��$?���C���|6��b��A"ΓT/�`ᴸ�f^� �����wϗ4��5?����˂��BfY^Lc"X�U�����[��G���1����?�Y?׫s���I�d�y�xa��K�?����R>Z9?	�87����Y�1�8R�>i���~��({��WH*�!�Z�r�� �uU�3-��G�
��3�y����<� ��Ϣ��p���n�G�#S�\��>���W�g7�8s�V�<����DC��玐:�L=?�:g�u���f�^���A�￝g�ܯ{B��[�Gn9����_�oƓ헶��Y��\��Qk��a'�95�'��%��R�cU���8�-=р�����Σ�H�v�^�]pp���N�O.�k�����8o����̥]�q�-�ρsX��Zp�YKO<�c�����Q���9b�8OF���E��/j�7������Ax@�'Γ��#�8-�s�-�S��;�+86�N��b���9�4{���Gp�1���G"Z矺ٳ�ݬ@9� 0�E>F�vy�FDc؉���r���@Ŏ^JK�����Og��D����>���6���GM0��눆�l/�ӣ3ʹ�:�1�_$�Q-��8����3@��:����S��`o$�O��?��!p����q�a�
��g۩?8<c�ei^����� Z�k����Ǚ���=_��M�<�	����<�,��s�7�^�A*��kQ���񸝷Y����r��&OU�D`�4���V>�M{x�i�7O7�oゃ�q��h.��霽>��w���ȉ�S�s~�H�0D�B��
��xZ0y�����D<�b�z,KxzP�7���4�~�I�>���[�|y�F4���lU��4���-���$Z��Hn6��6���S�ޭߝ����g�\B4_q�?NB���T�a%�xVPD�lc�GQY(�\8��B��QT�(��%���̶�����_��揚��}����w8�|'Mk�if�cw!Z�zG@�'��Q.\	�֞|�.�)�y��_O�s�JqO�^D�p^�U#҅�`���4ѻ	���/���[��wY�(��B{�`�)�Z���>~E�}T�;"\8yT�
�p��Q�*0�i�;1F�p4�y'���6D83��5'�#Z8���c4Gלyb�d��CO�Q,=D8/�cO��+]s�1r���a�����~D)�n��+}�x^�VGHxb0L��0��U<5��a��#W8FQ�0�`TCFS�0�`����+C��\a���D�p�� �+�<*?@�
'�����#򃌨N�dH�0�� 3��)�� 3�)�� 3:���x�~	���z���/<?0S�0������k����*�X�0چɪ����T<?���a������ÔU~����F�0e�0��)����<LY���a�*?`TSV�#{����ÔU~��&_�����<��H-Z�G�xV�0��]������x~�U�È!&o*�xW�0�������T<?� ���G��,��Q�"�8yT~��#�P���8yT~��$N� *��G��J��Q������ �I�<*?@d'�O�g,��8b��x�EFd'O�x~�5
��@����;�"�Ad'OW�0�`7C<?�U
�v�B����]�P�0���� L�<*?@'����ɣ�D0q�� L�<*?@'����HM��b��Q�"�8yT~�H&N� ���g����<'Ӌ������u���������a��Τ	x���3T<?ء4�v)M�����JS�0�`��<?ر4�����ɣ�D:q�� �N�<*?@�'����HC��|��Q���8yT~��'N� ���G��~��Q���8y�x:^��vب����O�8]�ð�]K��8�xb؎�	pn`��&�A���T� a�Ki���	p^`��&�Ah��L� a�DV��&ZY��8MR��d���
�QL4�X�3��f+pF/�Lc��%�i���D3�8#�h��g�m�����8nGD��#CVM�����FS�0Z���h��6������&�a��j�Ixr��h��6������&�a�AV���hY��V����Ds�0Z��*?`��U~�h%�����J4W���h��F+�\��V����D[m�s��<�(9U�G��6����J��F��0�`��$<?Xm4	�VM�����F��0�`��$<?Xm4	�VM������F+ъ��D+*?`������J���F+ъ��D+*?`������J���F+ъ��D�*?`�m���۟�|�b>׻0Z���h��6������&�a��j�Ix~��h��6������&�a��j�Ix~��h�4�0Z��T~�h%ZS���hM��V�5�0Z��T~�h%ZS���hM��V�u�0Z��U~�h%ZW���h��v�^�iG��K<�0�`��$<?Xm4	�VM�����F��0�`��$<?Xm4	�VM�����F��0�`��<�V��0Z�6T~�h%�P���hC��V��0Z�6T~�h%��F+1'�0b�9���QK�I��\bN*?`�    󊤝�"��)~�lv��a�Ix~�W&M���:i��J��0�`��$<?X�4	�V+M����K�#��W-M����A0҉�D~�vb6�#��M���'�,�`�s�A0��9�� �ĜE~�~b�*?`�sV�������ļ{i�<��-�1���|�a���)x~�{i
��^��������a���)x~�{i
��^����O̻���a���)x~�*?`������O̡�F?1����*?`�s����O̡�F?1����*?`�s����O̡�F?1�^Z}���1�Gʏ<?ؽ4�v/M�����KS�0�`��<?ؽ4�v/M���'��KS�0�`��<?ؽ4�����\U~��'��F?1W�0�������O�U��~b�*?`�sU��������\U~��'��F?1�^Z{�'�#�{<��0��y��<?ؽ4�v/M�����KS�0�`��<�~b޽4�v/M�����KS�0�`��<?�*?`�sW���������U~��'��F?1w�0�������O�]��~b*?`��P�������ļ{i��G��쑇�����a���)x~�{i
��^����O̻���A���^����{i
���)x~໗��A��'�0���T~��'zR����I��~�'�0���T~��'�����OtS�����F?�M��~����D߽��
O��Xm�<?ؽ4�v/M�����K��<��O��KS�0�`��<?ؽ4�v/M�����KS�0�`��<?�"?(�~�g�F?ѳ�
���Y��~����Dw�0���*?`��U~��'�����OtW�����F?�W/�\��y���1�4�G��^��������a�}��$<?X�4	�V/M�����K��0�`��$<?X�4	�V/M����P�����F?ы��D/*?`������O���F?ы��D/*?`������O���F?ы��D_��sS�gy��Qz�O�G��^����O��K��0�`��$<?X�4	�V/M�����K��0�`��$<?X�4	�V/M������F?ћ��Do*?`������O���F?ћ��Do*?`������O���F?ћ��D�*?`�}���(�<�(#���諗&�a���Ix~�zi��^������&�a���Ix~�zi��^������&�a��P����C��~��0��>T~��'�P����C��~��0��>T~��'FR���I��~b$�0���zi�$|�g�����0��������Ix~��&�A�A�^����zi���Ix~�zi��^��������a��T~��'�����OS�����F?1L��~b�����*?`�#����O���F?1��*��Y���O��K;?2��S�TZ�a���Ix~�zi��^������&�a���Ix~�zi��^��������a�c��$<?p�0���*?`��U~��'�����O�P�����F?1B��~b�����0��*?`�#T~��'��xƑ�?��8���'��)x~�{i
��^��������a���)x~�{i
��^����O��KS�0�`��<?(*?`������O���F?1���Ĩ*?`������O���F?1���Ĩ*?`������O���F?1v/���譏|�a���)x~�{i
��^��������a���)x~�{iF?1v/M�����KS�0�`��<?�*?`������O���F?1�����*?`������O���F?1�����*?`������O���F?1v/�}�'�����l�>�0�`��<?ؽ4�v/M�����KS�0�`��<�~b�^��������A�Aٽ4���)x~P���ĒT~��'���F?�$�0��%����O,I��~bI*?`�KR���XL��~b1�0���T~��'��K���7�TK}�#Cv.M�ð�]K�0�`��87ح����H'��J�0�`��81ء4�v'M��Ђ�I�0� ���M,Yd�fb�"+`$KY��X��
#�X��
��X\c��K,���ƨ%�XAc��k��1Z��5V��D����h�g�m�R=q�8l����CЂ��*�L�P��`�"�8y�������xn0y��� �g�xv��TQA&��x~�*?@�'����ɣ�D*q�� �J�<*?@�'����ɣ�D*q�� �J�*?@�'����ɣ�F*�����'�-έ>�?�`#�Xz�x~0y����J,��x~0y�������x~0y����QFR��`򘊇��'�x~0T~�H%���F*��0R�e����J,C��Tb*?`��P�#�X���ĚT~�H%֤�F*�&�0R�5��4^�)�8�@�x�A�AMU��H%��T<?���x~P�P� ��ZR�0��L����*���x~`��a������J���F*�����j*?`������J�Y��Tb�*?`�kV�#�X���ĚU~�H%֬�F*������<��ꑣ%/<�Tb���<?���<?���<?���<?���<?���<?���<?���<?���<?p�0R��U~�H%VW�#�XC��Tb�0R�5T~�H%�P���XC��Xb�0j�5T~��%�P���Xc�������'��0��$���x~P�����U<?(��a�A)*����a�Ai*�����rb-"?�tb�"?�vb�"?�xb�"?�zb�"?�|b�"?�~���AG�'��:��8yD~���ɣ�D?q�� �O���x����y�q�E=�K��ZV�0������-T<?hE����VU<?hM�����U<?hCă�'F�I������D?q�� �O�<*?@�'����ɣ�D?q����O�]��~b�*?`�kW���X����:T~��'��K��������a���y~�{i
��^��������a���)x~�{i
��^���m��<�~b۽4���)x~В��ĖT~��'���F?�%�0��-����OlI��~bK*?`������Ol��F?�����f*?`���x�Q��y~�{i
��^��������a���)x~�{i
��^����Ol����a���)x~�{i
�d�0��-����OlY��~b�*?`�[V����\��~bs�0���U~��'6W����\��~bs�0��m��Η����[���y~�zi��^������&�a���Ix~�zi
F?��^������&�a���Ix~�zi�����*?`�[����OlE��~b+*?`�[Q���؊���VT~��'���F?��0�������Ol��v~D}��-��푇���&�a���Ix~�zi��^��g0��m��$<?X�4	�V/M�����K��0�`��$<?�"?�~bk"?�~bk"?�~bk"?�~bk*?`�[S���ؚ����T~��'���F?�5�0�������Ol��v.��<�M���#�V/M�����K��0�`��<�~b[�4	�V/M�����K��0�`��$<?X�4	�V/M������F?��0��m����OlC��~b*?`��P���؆���6T~��'���F?�'�0��=����O쫗vn��$O��գ�(���F?��^���}��<�~b_�4	���Ix~�W/M���zi���K��0�`��$<?X�4	�L��~b7�0���T~��'vS����M��~b7�0���T~��'���F?�g�0��=����O�Y��~���[|������nɎ�F�����oF?���M�����7�l?�<?��|S� ��V�R�[}K    	�l�-%<?�շ��0� ����O���F?�\��~����Ds�0���*?`��U~��'�����O4W���h��F?�\��~���>W>���q����1z(�O����<?���<?���<?�<U�C����T<?�<]�C���3T<?���<?�<��a���� �O�<*?@�'����ɣ�D?q�� �O�<*?@�'����ɣ�D?�G�� �O�<*?@�'��,1�e*�+@�}�_- �!L��a�&P�$a5�&P�4a���N�� 
�d@S�@Y�H)�!3FK��)0b�e�L�QS,Cf
��b2S`�ː�#�X��EŚd��H*�$3FS�&�)0��5�L�QU�O������-��+�Y��.@Sؓ$ �)�I	��$��a
{�D�0�=I"B��}�D�0��$�a
�I#�x�$� 1La�L�X�O�H��0d��H,�'I$@S2S`D�$ �)�)02��I	��$
 Fh�>I"B��}�DD0���5��<��95�����H���FD0���5 �)�m�� L�m��`
ol$@Sx�a� B$߶�H����F�0�������F�0�������F�0�������F�0�������F��/�m�� 1L!d���/�m�� L!�:��4��,��@���a�D0�	Te@S�@MD0�	�e@S�@CD0����&���ƺ�A� La��`
(d@S0�)0R��d��h1V��#�XMf
�c5�)0r�5�L�c�@2S@'��E�	$3D�q�L�d�@2S@D��^��P�y/�z�[�ǑKi5.@S�����M�)�_����Վ#_�C!���g�qUp�;���c����e�"�8��!
}}M� !D���) D�qB����B�B__S4@Q��k��!
�2 �(DȀ�2S@'����	$3D�q�L���*S0F���)#�؋���h�Ee
�H4��2c$m��G����y�y0Oʷ�9����0۶-B��mۖ !L��mK��`۶@�D�mۖ !L��mK��`۶%@S�m� �)ضm	����F+2S`$��L��h�"3F�ъ��F+2S`$��L��h�"3F�ъ��F+2S`$��L��h��֏+ρ�Q갞/@S�.b�B�jQ1�V��a
�ɀ�P��a
uȀ�В�a
�d@Sh2S`$��L��h�&3F�њ��Fk2S`$��L�h�@2S@$'���ư.3D�q�L�h�@2S@$'�X?j�<2?R)���a
�,��Y0 D�q5��Y0 �)��`4@SXg�h���΂� 1La��b��:F�0�!3D�q�L�h�@2S@$'����	$3D�q�L��h�If
�DcN2S`$s��#Ѹ2" �)�$3F�1���x	���>.@S�;s� b$�ΜJ���w�T�0��3� �)�̩�a
;s*b��ΜJ���3� �)�̩�a
&3F�1����l2S`$��L��h�Yf
�Dc�2S`$s��#ј���Ɯe��h4�,3F�1g�)0�y���h��#�<�?1�y���b��:S�0��
� 1La���b��jk������ 1La՜5@SX5g�V�Y�0W�Bf4��L!3�9T����*SȌFc�)dF�1��2�јCe
��h̡2��h4�P�Bf4s�L!3�9d��h4�c;��E9jkV��a
+Ǧb��ʱi���rl �)���a
+Ǧb��ʱi���rl �)���a
+�&b4s���ј����\e��h4�*3F�1W�)0���L��h�Uf
�Fc�2S`4s���ј�����d��h4�c�g' 4�a��~b��ʱi���rl �)���a
+Ǧb��ʱi���rl �)���a
+�&b4�ʱi���e��h4�.3F�1w�)0���L��h�]f
�Fc�2S`4s���ј����<d��h4�!3F�1�)0�y���Es�*~�t� �)���a
+Ǧb��ʱi���rl �)��a
�rl �)�ʱI��F_96�|��4@S�$3F�ѓ��FO2S`4=�L��h�$3F�ѓ��F7�)0�n2S`4�d��h4��L��ht�����+�vn�{��z���0��c� 1La��4@SX96�V�M�0��c� 1La��$@�F����a
+Ǧb��ʱi���e��h4z�����Yf
�F�g�)0��2S`4�e��h4��L��ht�����.3F��]f
�F����F�9��y �%;jK^.Kc�F�96	�v�M�0��c� 1La��$@S�96�3��sl �)���a
;�&b��αI��*SpF��Ce
�h4zQ��3�^T���F��)8���Ef
�F��)0�^d��h4z�����Ef
�F��)0��sl�%�rt�]x��kl
�'�����	�Ŧ�aX�N�	xyF�%6�v�M��P��aS�0ag�<A�6���aFo*?`t�����e���F�ћ�QFo*?`4�����d���F�ћ�AFo*?`������c�]^k/�����"_����k �!������� b�}��$@I��5	�vyM�Є]^� 1<a��$@Q��5	���9F2S`�}�L��c�!3F�ч�9F2S`�}�L��c�!3F�1��9�H2S`�#�L��c�]^� �9����0���5	�b��@�c��a
��k �)�.�I����&b��.�I����k �)���a
&3F�1Lf
�c��9�0�)0r�a2S`��d���1F��#�Yf
�cd�)0r��e���1F��#���6^�6�J���B�c����c�]^� 1La��$@S��5	�vyM�0�]^� 1La��$@S��5	�vyM�0��#�.3F�1\f
�c��9��)0r�2S`�#d���1F�L��c���#�!3F�1Bf
�c����z(�#���<��1�*�i����k �)���a
���b��*�i����k �)���a
���b��*�i��Pd���1F��#�Uf
�cT�)0r�Qe���1F��#�Uf
�cT�)0��Qe��(2F��#�Uf
�&c�����y /G�í\���"l �)�j��a
+[�b���i����e �)�r��a
+]�b��j�i���e+��]6�2�rl �)t���4F���Bct���H4F���Fct���h4F���Fc���0���>�Z���@��ͣ^��ƺ�>h��P�������B�B]{4@S�k�a
u�}� !L��� �)Ե�A�0���>h���2S`4��L��h�.3F������2S`4k�L��h�!3F������2S`4k�L��h�!3F����
P�G���|b���� b���� b���� b���� b���� b���� b���� b���� b����� b4k����X����Ze��h4�*3F��V�)0���L��h�Uf
�Fc�2S`4k����X����Ze��h4��U >4n))wW �)��U@�0���
H����V	���* B�B�[$@S�{��a
}o� !L��
 F��� �)t�)0���L��h�]f
�Fc�2S`4{����ػ����e��h4�!3F���)F���)F���)F�������/ őGO�^���:� 1Lat�b��:�\�0�uйa
ct�B��X�k��0�A� F�q$�!La���5@SIf
�F�H2S`4G����8���Ƒd��h4����8Lf
�F�0�)0��d��h4����8Lf
�F�X����_ jG�\�_���:� 1Lat�b��:�\�0�uй�a
�s�    �A� F�q���5@S�E�0�ur��a
Yf
�F��2S`4G����8\f
�F�p�)0��e��h4����8\f
�F�p�)0��e��h4����8v쫽d�0���v�K�0��� 1LaǾ$@Sر/	�v�K�h4��� 1LaǾ$@Sر/	���� �)����Qd��h4�"3F�q�)0���L��hEf
�F�(2S`4G����8����Qd��h4�"3F��m��
P����/@Sh;�&B�B�96	��αI���v�M�h4��c� !L���a
m��$@Sh;�&B�B�96	������d��h4�&3F��5�)0���L��hlMf
�Fck2S`4[����ؚ����d��h4�&3F���`�x�ԣ7�Kc��hl����ax���)x��kyF���X���!	����a8�N�)x��Ky
�!�P���!����a��P�#�؆�]�6T~��2�!�ʨ2�!�ʈ2�!��h2�!��H2�!��(2�!�
	2&�TH�1���2r�u��΅Oy���[�#y�Q/@A����BB]�5	#�XWyM�p���k �$�U^� !,����	u��4@O����B�B]�5�Lf
��Qd@S0�)0r��d���1V��#�X��9ƚe���1�,3F��f�)0r�5�L��c�Yf
�c]�s��@}yo��0�U^� 1r�u��4@SX�5�VyM�0�U^� 1La��4@SX�5�VyM�0�U^� 1L�e���1��* F����9�2S`�k�L��c�!3F����9�2S`�k�L��c�!3F����9ƺ�kg��@�Y�� F�����a
���b��*�i����k �)���a
���b��*�i����k �)���a
Ef
�c�2S`�k��#�X��9�Ze���1�*3F��V�)0r���L��c�Uf
�c�2S`�k��#�XW��|v� ԏ�Ӌ �)����a
��b���zi����^ �)����a
��b���zi����^ �)��b�k��#�X��9��e���1�.3F��v�)0r���L��c�]f
�c�2S`k����X��I�:d��h2���:�?v�y��qb�|i���*_ �)�̗�a
��b��
}i���J_ �)���� !L��֗�A�)ˀ�В�$ϘT�� }Ƥ2�	4&�)4F��%�)4F��%�)4F��%�)4F�������Lf
�Fc3�)0��d��h4��]��Pyd�Gϩ�|"��r�&PȀ�0���`
�ʀ�0���`
�ˀ�0��
�h��CE �)L �1L�e��h4N �) �Hf
�F�����8�d��h4N �) �Hf
�F������#d��h4N �) �Hf
�F��$I}t.�� �����֮@Sؓ$ �)�I	��$��a
{�D�0�=I"b�$Q !�o�$ �)�I	��$��a
.3D��m�D�0�����6I"b���L�h|�$� 1L�e��h4�M�H��2S@4�&I$@S�) �o�$���Ҙvs��QZ� 1LaO�H���'I$@Sؓ$ �)�I	��$��h|�$� 1LaO�H���'I$@Sؓ$ �)���ƷI	�\f
�F��$��a
.3D��m�D�h4�M�H���2S@4�&I$@S�) �o�$ �)Dٱ��ɥ1���-�cDw���0�eǾ$@S�@ED0�	Te@S�@M�h4��� La���ؗ�`
�d@S�@Y�0�!3F���)0�e�L��h,Cf
�Fc2S`4ː���X�� ��$3H�1�L�hL2S�4����=I�>8���Ҙ~�����Hy��a
k�D�0�5I�b�$Q uF�qO�h���&I4@Sؓ$ �)�I��$�a
{�D�0��2��h4�I���:�Ѹ'I$@�F�$� 1La�L�h�O�h���'I4@Sؓ$ �)�I��$�a
u��G�������V�Ѳ7�� D�� ���	u��<�@���*�%�UC�� $��������.�a(�J�Kx��J�� X�x~`*?@�'��]�ɣ�D�q�� Qe�<*?@D�f� ���g�o��<�oُh5j� 1am�� 1am�� 1am�� 1am�� 1$am�� 1,amĕ !���Ȁ��6�j���6�j���2S@4'��Mƨ!3D�q�L�d�@2S@4'��M�	$3D�q�L�d�@2S@4'��MƷo��m2.���������GU	��WU	��gU	��wU	���U	���U����iU�0��mU�0��qU�0������yU�0�������U�0�������U�0���-�lg�?��o%�DO�E��&��� ���[JG�H�]��`k��^��{�v���+�0[�X �)ؚ�� !L��4�a
���4@S��2 �)X��$���
��d��e@S(2S`4��L��d�"3F�ъ�MF+2S`4��L��d�"3F�Ѫ�M�ї)<ۈ�dN�ҚS���bvY��h2�����f}��)��ο}��+�h2��M�<\!?O&�z�q�Lhi\���X,�g?�w�荨�y�Z��BDP���ހ����k��}w��כ��
?�O_��n����}�<Ed'�/�g;n�_�\nޏf��2و�2�H��F�������#��$*��������v�֒_�u_���S��&�udJ�Q� ��-�O}�XD�Χ���.���f,�e}~��8��cĕ��e�X��F�'D�V��s��"�3��2�>?�F�E9�N"�1���k���R=��w׈�'�$��{~�G>���������z���וq47�׻���W;7�����������.(c�B�p�:�i~A!��|_������]<���ʸ�8���ʕ� ��uDY�D!#b��A&Q�da5A&Q�daA�Z�!d�����t���4Z�9��hM��V�5�30j��t���5�?����M��f�5�30���u���6Z�9��h]��v��=�~�3��q�(���z�1��֫������л���}��0�����tDgYG�p��:"�3�30Z�6t���9��9��hC�����30z�6t��:�sF�1'�30��9霁�t�I���cN:g`Ts�#�Ay��R`��cޫ9%@c�{1�!y�� !|!�Eu �.앜 �-셜 �,�ˀ�`!b���Lf
��c6�)0���d���:f���꘳�Uǜe���:�,3F�1g�)0��9�L�Qu�Yf
��c�2S`T�}���'P<�r��q�Nɨ:��jG��}��a
��Q�0�t_� B�B��tT !L!�:*�����@SH�e@SH�u� F�1u�)0����L�QuL]f
��c�2S`TS���ꘆ�U�4d���:�!3F�1�)0��i�L�QuLCf
��c��l|�������"�*�t_(!b��}����!�k����Ք!t��k5%D_��ZM	B�VSB�0�����D9!������`�է"�3L"�M"�3XR9�$B8�%�3L"�3��&�L�����r�I�pS9�$b8��Rw4�3@ꎦsH�q�ی��`��[J�����C��M	���M	C��M	���M	C��M	���M	C��M���mJ�����a
Yf
��c�����2S�]f
����L�st�)@j�.3H��e� i9�� )G�����2S��c������圷�1T!LG�p��:"�,����#b�B��ʈ !�h:"�1D�1�!����E�����30B�Vt��9Z�9#�hE�����30B�Vt��(9Z�9#�hE�����30b�Vu���9��|�g�r�D�����|���'�k�� �  p?i\C�p��j�ΐ��@��^(!b4�^�!B8CڕJ��}������QB�p��sDر�7�i�ΐu�H;��� F�1e�]�p��� H�1�,�w�:���΂ �Ǭ� H�1�,�x��}�W�r;"�4.[� ����G	��%Dg�/�1���QA�<�@J��p_)!b8�}	����>tDg���1�!t� �=�� ���9��:g�C���c��|�3 ���H���c��|,:g`$S�9#���k ���G��vb(�}	��a��
 �0�@�| c��}������
 �-�W?*��p_�� b�B5Cj�1L��L���TU�`��c�*S0F�1U�)0"���L��xLUf
��c�2S`$S��#�����d��H<�&3D���>���~t��{���c�(�(L���!x��}n���w�<��!X���*�$LW�a򄊇����x�0y��� ���x~0T~��:N�0��)���QuLI���cJ*?`4SR�#阒�AǔT~��9���F�1%�0R�)���r|�ԗxʑsO�_��p�(�!ǷP���a	�P����	�P���a
�P����
�P���a�P�����P���a�P����Y���㏡#��*�1�!�,�r|�H�ΐu	9f�AB�YgA��c�Y$�u	9f�AB��PI{�(�1��G"H��*�1��*�1��*�1��*�1��*�1��*�1��*�1��*�1��*�1�!t� 	9�� !��9$�:g��C���c�r�3@B��sH�1t� 	9�3@B�E����=T�_"ꇕ���r��J$Dg��J$Dg��J$Dg��J$Dg��J$Dg��J$Dg��J$Dg�K$Dg�KD��c�9$�Xu� 	9V�3@B�U���c�9$�Xu� 	9V�3@J�M���c�9���dΐ!1�&s�̨9����9��D�(�1��/Dg(=tDg(���Pz�!����#B8C�]#��.i��Pv�HC�p���F"Fֱ쾑���C���c:g`���9#�X��m�2t���;��sD�q��w��t΀(<N"�3 ��H����$�9��8��k/գ[x���.i��Pw+HC�p��kA"�3�4tDg����!b8�. i�ΰH"F����������!b8�霁Q��sF�����j:g`4 �霁Q��Y��d�:g`t k�9�Y��Țu���@֬sF��Nɟ'����|����at ��h�ΰ�:"�3x�1�a��4Dgؽ �v/HB��@���1�a��4Dgؽ �\��du�30:�5t#,�YC7�2:�5t#,�YC8�2�!t#,�YC7�2:�5t#,�Y]�Ƈ�@��IAg����ν<D���VⰘ]fN�r?+�l�|��n)�S�+���l���y"KGq��{!"8C���g]b�Gl�[���.Dg�D�w����5��ԏV��q!"8���;u������CK7˓�H�G�
A�P�s(Q���
��Xl1��f���rʷTo��"��T.DK���٘����49��g"�%��w�� ;�vv{�s���v~��� ���]?�l��g>�찚�
��7���χ�g�#�{�,�ED$z?�l�����̎1�["� ���`)���.�,΃���
���]�� !���SN���K"�8�L�0��e@Q��� 1\a9%@W�AN	Cv�S�0�"3D�q�Lz�@2S@t�U�) 2�Hf
�����"�8�d��h<N �) �Hf
�����"�8�d���;N�=�~���P�Y=J�/t�����c�]��1\a+D��;N��#b��.Vj���BG���VtDahUG�0��tDeh]G�p�&sG��u�38��8�t΀�;N"�3 ���H����$�9��8����j�'D�n�9E��B�p�]P�1�a�5Dg�e�vAYC�p�]P�1�a�%D���$r�vAYC�p�]P�1�a��w�D:g@�'��}�I�sD߱�sD�q��w�D:g@�KN:g@�'��}ǒ��}�I�sD�qmgx�+t\����-�[����^�����:��
�����R�V/DgȻ	=��
}F�oe�,���r!b8�nB�g�B?$�~�2_��B�p�Et�$~���	��}�a����vC�BYA��O.Ι����wK��r���|Υc�:_V�a�I4�H4� �a�RV��D}>�B�����`_!�#�B�J�}�h$/W"�,���
�Z�O�,����
QXn"�,�;�
Q�q���P⫿�a�ϕ���F_a�H�w�#�3�U�q~{GT�Y��~f>Z*�^,v�D�kD�=b\�:D�q�/y�>�a�Id_#:[2�C�KY������'r�^#�3�ŏ_!�4�DgX���B4�_�ΰ�(�^ueX+��ޮ���k��W���+C�:�/]��/w��8�/>ά�E�]�I���9Ow�f@t'���\f]�ҿ�%ƻk�P��f+���D�c����d`(�H_$��:���:�տ@TS����#�H4��.�����>Q�KD��%��wܧu�(G�X��϶�
Q�z�1*�e�;��Ky���kgT��>���]��0��:��WF���EJ�.�ތ�c��w�ש F�t��_�w��_|z�Gʥ���cM_t�5���}�Q���:OT�CG�$�gu8�s�F���e�e���%=�}HT�1r�����}F|IO�l}D4��J�-]FXF�q�_ғ5[�h#j��30�������=>$�~Dj����H>�s��=[)8i���~�M�ǣ�Q=����_�v�E+�����`l�݇�� ���xH�O"��K��[���<h�B�`s�1�NC�ؐ�G�����#��      �   
   x���          �   
   x���          �      x��}[�]7r�{~�����~�<�b�Ւl���K�%�L�1�������CV�{/r}�<Tu��!F���X\�j����y�����>}��?����_~�?��_������?�����?>�������/���������}���g���叿�鿷��������/���W?�x��7�_����W�~z��7�ܢ�[�{�����_�j�1�)��w������\��ǿ���VR���<�?lLU�i��lPNT_kcJS,� &�������;���) �������� e�X(<QQT���y�2�hi�R��Kڠ\���۱&L&����&&�*�3tH=T���2eߗ�F^&��2Y�T51�49@�e��L9C|�FR;�^�6}�r?1�q�t���?�x�!�!ob��/�?. ��J\ΰ������8�Y�F��A�����c���*�_h��<f�q�I�Bs}9\�����qr��>��=�4~Z���֙|ږU𡵸��58��\髱���������W���?�r����Ux��k�;�S�~��y���p���	Y=�*��T{:p��>���P�H����*8i>B�U3*E��s� �X�O[�PU��.TFL�9/D�	)���Iеm��k�?=gƽ�gQ�r���h�!�(��Dh�}�R��:H��]Q}�薰�e.��-�/,��j0?Q�g^ZAᷧ�;��F�7p(�3�����ST�9��n{|���P�#�`Π�r���S�)�;����0Pz�7�m�T
�2��Ѽ�J��[oG�2�{� (�x����i��2\{U9�[S���e\�t���z8��vƍS�J9�ۑ��y���p��cyș�<^'k�<-�j(����F4h�?:~p���r,�[�ʶupW���\�4 M^��2�F�x��G'�����8�^x�Ngm&��zX'���!��7L\����j?1��D�1�t�-�s�Ҩ.�e�TC8W�8\�$���;&��L����F5���4��c�2@R����0ڗ6 �a�L�R��>����� �ߜj���!�7�%<��U��T�T"�*��ނ��y����ã>LUF\&��M<@}؎�)W����$8L�K I5�S��w�X&�ˤ��~�{ɺӫ��WX�;W��NI�9�j��l�sǫ�aP�,	��0���N��B�2p�vB��s�U�H*����<�T��K����<�s���Ճ���A��T8	��dr$c�p�����q�e2�s�!<Vxc�˗�v�zu3'���H�B�/��^l�41�7=
��iBūL����ˮ,l�4�W�m���lgW�I�� ��g��^]�[�H0��^=�W��HJޫ�p�g$�|@ym�J[���ۉ �^;�[g��*c��
'�(n]Ā��2a Ў��½#��8�c�u�F���'<h��v��@�]��Z	�!�f�9$�R�v���Y�/��fP�gz*�`  L��}q
�t#�u�HP 8�z&�N�t��z&(� ��N�̠�M	NT�C��1h�kS2aS܀O�.M	�7������ե)�����u��DuaJ5�%�'�w��
�a(�ǅ����ʁ�a�p����.�I=��t2���#Lp�E�8ޕ�X| �!$��.���)cmldt)�u5�x�7�v��_���fϱ�v՞I� {�Cw@J�r��Գ������H=�����4kc4s^����.�g/^=�敽Ygͻ�s���7�F�y�&�ϐ���)g	𧻓�~�R�<�E�燐/��]��ӹR-\ߵ8���V�7��sn{�Y��n>��E�y�a`Pmi���=��B� ��6�OQ�e�x��	X���a9<�e�Wjx�^�EU�����4�m� �	�!v���� -'����)�'��q�Sr�l;R¹�BM�V�qA��)�!���(\���}�����Ǝ��o#��8|�z췠���q��)�7�,���	��[b�;,3֔�f#�Pq�������:�٩�l�b!7n���7?��lѡ݆Y�C��n+� X]#j^L�d�J�,�kXC<��e��Ex��c��ۧ����-�g��OKrKޠ�)?�[h�^ϗg:S�;Ȼ�y�x�.K-B07���3���m��g�[5�{х\0�
�-�*Dրy@�p�
3�o9A\��\�5��E�оk����)vJm��d���k���\8]�bNTڦ��pR!S<��/�7��*&��}����Nn9�z/�O�֢�1��o�eݟ����[����Eyg6������:��7c�ň��e&Oe]Ō��A�� ]�=_6RI�UBg M]y��c�Ik���8K%g�q�T)��-��3[X�4e};�@��ٓ2�9RSqG�{ߠ�6�5-fA(��G���-������(�Vx����*�̘w���B	��[vB"������\&���6�(��zՒ< Daq��Q���-���͢�W��@�p|X���;���ʕ�?S&k�P�6�$ޕ�)DFd�$����B����v�1�ee�I9��K�NK��=����],�C_�:ө��=[�
�M�'&�W���)y`�S�
 Q
��j� �����.:^���0�a�	G �|EIgI[�&c����R}�M❖˭o
��8��$]%J���$��>W����iK��.�z����o�y�u��[���lӧg����j����8�~�c�?��Fn�GL
��W��n]S�����u�
W7�G)�V��d�[�MHn��(����0��;l�=�PM����%��ώNyL��}�ē�P��w�1E����C�&qN�D��^3G9��,`��[�l��
�%���H���ʀ����C�^���j#}���i��{�k�N�j���+�W|�j�f���8�9-'[�\�~����<I�i2�Y\|��H�o����
��/%]a���:p��g$�$�>��ٔ|>Ӄ�5���E/-�p��o��OT��u|n�p((��]P���6�Q�R�OG� 8�;�^Q�w�X+���`1��i�+*��d����J�Y��������G��������&�K��7���s��|���7C��r�{�P,7X�K����Ğ�ii��4�>��[��CjYz<�Q/��+?�WH"x��C-qG�T��~�Q4�P#/n���r.���b�<b;DQqnQu���Ӭ�z� #����>�S�o`�О��@ϋ{k.+U�9-����dcA�]�}��`�������@��=;,���.�'H�Қ�K3��-�&���c�TBh�!p�A܋t]*ۭH�8X��'lъ�e',�����^;�ߍ���=��A� �a��r��|�dǁ!��@���YL.xH��6bd�$�U�`��-`%���_Sd�����y�1�/�P�����>��*��qkR����ã��ܸq%g�,@��o^~���[^|�H7w\�a���B���n��t��>M�H_�D�W�NPo_}���W?����Л	�^@��l�D�P�>��b��:��L�����������B9ޣ�7�@,g�L/^�oϢ�:�{	u9Oz��c��u�ۋ�� ]��Aܜ��MˣB�ͱ����^��GE�JV��o]`���5�慡3�OO~���~w)�<,���=T��^��ڱ����`����� �5���؞��;x]�1s� (�h��k�	�Õ���i������O�<��o��=�#zV��
⎥���c2�X��ڲs�h��w-=a=��<����؏3$�j�mK/��@�d��gw.��zg^#�ay���OPz�}�
����j��y��]L�S�w��\x���p��һ� �^`��rҙ���
�^` 6�A��R;b��v"*���0�!#*��c��M�Z������<F:6�YW�j��y2�H]�w�_A�7Px�P��+�[�^@�w��B�Q�nE�� nf��rU#}� �q�T�:�z�P0_w�tqC���n�>���ւ+��(    ��c�a(Υ��N���A���z�Pт�������v���S-���z*|���G=��E7�:A�����^���~���2eŰ�� nk�I'O���<�e���ĭM�˯?~�6ߺǏo�&F�EBX-qs�'`}(���� .l���$����F˷ nq�9Q���/$��f�t/���w�?�2�ZT�i+*C�w:�\r�/�5;�ؠ��ϛ�E�of��*p��+���\i��G"j=���I�T➧��D�0δ30��w=�\�7���8S����ˮ�+iͮ�!(n����؍�0�
+����gU��a�E��g��&SD8Q�Y������9Z�B�zҎK6j���5�x��gj̋o����7 ��#���i�i����й�NW�e�g+n�(�ؗPj����	b[�иgY݁�"0��	�_��z_��S����I��'OwbU� ���uJ��{x<?�Fƀ�Բ��������;�T/��x�����`A�U)�+K��ť� ���U辫 H:l��9�ȭ��}T��� b���8�ŵ�;��+DQȵ I���P����5%'������7vl�@�Aqd� X!q)���ߍBH9,RK�|������E�-�������7�o�W�x�v�9{���Y\���W� _p�t�4��z�e_� �iOS��nl�e��燎ˢ�}�
a��3�нPn,Y\ۺ��@��U�{�s���+��� ���)�7ĕ��mZ�	P{> ����lG���n5��Ƃ���pxt׮�[!�o��rmy˸�F��>�8]������i�7�����F��yq�*����Iv��� ��UwPi��q'*~g����ժ���J-����䐸\���Cݶ��Y)|y��U?�R��_惎龸Z� ��Ǜ��w�Z��4lb��N޸���ڼ0 �e"v�Lą��[���T-���2��A�C�Âzڽ,�Rݿ�u����8��T�uz�שw$��� /��'�R�²����Y\�z�e6Xftj��W�����j=�/�I8ݬ� Aj�8���Up��E���"��*)/s��	�Xo?7X��^�1
q�4c����~���}�rNϘ���)\C��&����_O̴�[=���,ՙ�k�ט�KۘJY�G�}����0��`Q2 ~?>1�r>�iF�~��9ɨ��ɞW��x�3�d��8=�.�[�˩算2.���Է�]����}���߮�"���r���2��88zpL��s�����H^g"N��k��2Q-����e&�o�
1�����=1���=`J mw����L�{����7A�W�X��0?V�sѨ.+��Ǣ��L��άo�	þ��ހ�||,w��l�>���׉�gz�a��V̉3KxS~x�����A��`?F�g��#����n߼ym]K|F��-�$%\1�'����|sN��P�屄 LZ��c�t�D{F֔3<����{��C��Z����i�ݥs�x�R���tg�>w�(��~9��r�y���u �'s���Z�w�c#��E4���P"C_o�GF��{�C�`�H~����Q<�[�Z�ZJ��*��ӀH�z�#���iT0ۅ׊�����v8k��M#�]�b�;_����q�(��g��r��#�t�Bk%�o��h
��8i
%B�s�i�|<C�����kL���6�����5Œk�̶�Q4T �(��m@�&q��}XS8 ��h!�X+�� �s�M�j���U^m�M!�0��]�I�Y�8c���?%e|+e���K�V�$-DT��3s�S���֏Hd�u�DE8V;3g�Z�Ռ��#�75�ͬ3E:�����|~L5�����h�,�a��ã��pF��sf>�@�B����Z�0�Y�{�u�����d��|�6�v���(���ME��m����1,���� �J����5�`��{� ��v�
��b���N���x�=�9���*S��s
M S&����������]�F�(�P����r�
��IZq���m�Q��Z�t�w/�tʗ�C�s)<��W$&/��P����9��8�����6�S�4Z�[N��,֤�upH~�g�����9Im�9\1���Z��)��No�Ŋ��5��P��;	��H~Yqs�a�~�oo�L�j�>Yĕ�j����X�5�V���>��[��nglX��i"E�����p��]�Jq1�U��pۀ�x+��ξwH!:�nt��R¶�H���s�>�^��˕��L�K�59���-��>��E��g�|��uz���U�;ʞ�ՆMhSX�RO��JGw�q����2{N������������-,
^F�qV�3.��g!.X�ݙ��t�!�����ܺ�f��*�z˨ŋE%JJ���RQ��' ��R���FoVB��
�EYK/0Wʙ��\Q���D��r�"(��p;�����A����e�{�
�|�2k�'0w�^|����;�Q�Y�.'[<����Υ&��B�UO Aᑣ�8�4h9����$���YuP�2^mI:�;oG��9ȀK�q���iT3"Vߍԗ}do DҲ��-D���R�jH�Jh�ߤ�j{Ɉ���s�E���iM�֌2B�&�wHq�D�H.(Z3�5���K�k���c�v����+c}�}�������%|c�N�"���Z7b�L.�:�B�X�?�k݈�}�Y�u	b:��neͺ��7
YmQ2R��*[!��t�:q�8 D�?ID9F�[J�0F�)x�:ַ�����ao�&�����k,�L�I]j�f$�]Xz���@	�r4'�x���|�'Z �hnZ�Z��J��ԩ�PP��$鋅t��>*~ ���3~奥U@O5��°��k�6>��^�8���`���������3yY��q��u⎻�߯�k����=W�+Y8���6lＥ�E���h�x�+gT�3I.a�]��Z�l�(�$+��� n������	.�ϯ��{<�z]�\��\8jV����'��9���o	������-!]���uȶ�w���#�HJ9I�����T��xHYil>�W����'G�ز�l���B��_�]r�@����;hD?hĥ�J���O�"�ŏѽ.�I��.��ZY��hR���J�xh��n]@ܶ�(#�����M�2����X�LS&���Eg��]������
���7."iq���v��RG;/��A^gz�,ݘ�,�]Fδ` �t��^yR�����'W�# �2��'�ws9X����F��{���ǝ�O'��}E���#��8i{�$T�c���<��vn�8y�
��|�.Jsw>���&P?Y���'���\��A�~����%NO\�č�t+�c287ل�(ߑ6quo����M/
�:c���9�}�#:�UO�Ŭ�Բ^�Y�������[0;qQ�)�������+������kp������ep=���/̑��<`HŖ�vb]M�.`����<`f|��qR�SPF`dmq*�l���Рb�%i�����v�B7R��"�í}����|�F�8U�%��|���|3�-n�Xb��4I,�������*eb�%��h���Y5�,ts��|Q<rx����l�L�Bv�B�O�!~)��m�sS[�ii�T�.6��"��K �G�9A�X�j��U-(&������/��hC�9�xV<�����1�Dw'yl R-x�
e8H�0���ޒ5d/�����U����[l��
o~�<�\tS�f�V|
������G_�y��z�'��l\:;��]}�2�����UH�Yq��f��a��&�=�[9J�z}���@��P�3�,^�$��T�
�!OL������a��硟g�l����w.£۞���y��r]�2�'�<VK<�}/p��\U-ޏ��8Ad���0W]*�zn_`�*
E��Byr<'�%�),��7�S��û����ES�\�ӻY���}��&����]���xI��� �x�v�Ѹ��c� al����R��w8Z4�oY��!���;�afqE    ɗt�e���ӱk�ZAS�\D�<��V#��!7�+ ]W��̮"F�c7�$�UJ+�`y`es��iۺ���G��zXq1Y�jT'��:��ɹc��@��z���	��9")����y'�1>�J���U�d�����o�;v�	T<)����ΒZ��f�-Aa؉31�K��Q���)�I�ӥ��V����ɗwrXj�%1�}�D�Y8�(Z��h�12�݆���x=`��X;��f��VG �R;�K���Nn�^>~l�x�(19�����U��|���`�6�H��^)���,���c��G|�<�ܤ'���C[�8T& ���R;Ջnr��Q(�v�k,�ꉱ��k���]&KaI\�u��YI�4���̚7K�TM����.:bi��ø�b/l��g_���b��'�TQ^!���-Z���!�R����� �Gk����X�,O����񬔴W}]|x��r�eԀ;6�dq�jm^��{α������}m!<6����~XV�#���24�lqsi]V��^�&�<�9�'�Yqs��:��m���@���a]fV��U^iS�K1������5򸌣f��y5��B�t�u�=/O�퐁�!$X��g���8*q+0���ň�e�$G3�+���?��>���6��)t��U��6\Ѱ��S7���R��JALe��M�95�����H��s�B3�PAҡ�e�
`B��a��"�޴t����]�Q<4�x�����s$l;�	e}
�V����8����bt��Ý����;�%,�ZA����Ǹf��/�A�W�h�J�v��l���B�HU]IF�g�6�T,�-�xưY+qv�E�&�u|�1K�h��52U�<rL�"/�X�R\��^��v�ݱ�����&�;^�F��"l�I:��u�QȠG{��pi/�\���K׮��,WO��O0���jp�z-x�����LQ^���������U:���K����Jg��`^>Hi���:L�*}�/@T$y�x���s	���v�7N,%��c#ӭ�6���CtV��Z7Uy�Y���cAߋݞ�x,t9��p���쉫E���%=Cd�^��=�ze��}�%�z�SJ?{�[�l�ڥg�p���Ǟ�_[Ҍ�>ɿz`��w�n��x�{���I~J��AXftH�%YMd����V=�U�a�84O�.�����%]4�a�SCq��k�5D��]h"`v�����(�;]Jɝ+Ի�pг^��$8Z��(c���#��5��2�	�\�r�&h�)/o߽��N@WCl���R� H)@Z
kqC	y�v���t�*���~���d�>\�}ײ��3j�ڸ�s��{���p�NA=�c/���x��H�1`,/��^ֵ:���/��'��|~I��:]f��17�6s��b�*��lE�|h=ؒ/�\f[����>�oI��fO?2�Q�����*���Ab��7�$�5�>��`�R����-�RF�]�N)0l�@�'�7�V����cLv���u~	���G�?wf���?�/�C������w�6$�҉�VR�W��\R��ؿ!?�c����-G�~�����G�" �CK�?�e&�6���\�eϩ�k�1��,���'uQ:\-�vW��g�J�4��.�R1w8��3Ji�Wy�m/���[�4�{��7�N�2���RP�u#!%�1%<�ɪ��O-���w�5�������M���h��oz:q^�����]k��Y��,5 ]������oI�� I�Yw��B^��\�ޠ�QT������ja}����B��ݏ��m"��k���͇o�B�Z+�o��� ��aA<a^�mCD��GBa���P���1�91�O,	E�j���<������0��TC�\�����I�c�E���\$N��#�����i��@�W�pg�N�;��' qF�ކao�,����s�I�G���<x|�܎i6��m�z��dл�U���C<�^0�3�w�+b�	P������xx�r��<����_�>p��[v�`}*���D���*KF��x��A��rSdd����1SчJc�f����6�w�C��e�z�
~{�`l�V=�]�߶<��|�����*�i�\C~2띏k��Y|���*���K-�j6`*/n���G�k4� �����.���S�x�������8�F�{���"mΰ�!b#5t��Ǐ����Rh�wL;>��D<�@�F�7���@��>��a��'iꢟ���y�����{p�܈���h�JrT�v�#tġ1^�u�I�}��2Mʋg@�j bn��A$���ɔ����+�b���y�2%�%���O������5�f����)�����.��^po��s^�)e��%.�\�]I�ש�V�7�z�YgQ?�!#^�%��=��gS�x��Ԃ��zbb���V�!�Xd�	U�z��W��a�et(Ƒ~<5�W+Ԅ�(�!� ��o!�/���d�<퇒~_=H��*��E�.�U���}���c��'��~nNg�0x����S�u+'�s�.�G��{ �a5AԘ�≦	l��JPO��2�ȫ�B�z{�w�<���<�_vq����@܏c��=Џw��ISϦ�~�����W���P{݄rX�N��J�r�dAA"�M I@hp50y|�)J*��i���Z��jc��Ďe���47o�.s ?-#�Ǆ�e�B���w0��b�(S^|ƤyYX� QC�8�X�8����D$�!�y1����ӛ��[�^�֝���򀹺^�;=����t�.�v�#8��Q�N���|"y��c�ܴ-8�I㢸N�ߐ�c���!��+״H��8��i�?��cpRF_�������{�2Bjb��^/�`���$�g����'GX����b�g�w5^	GbL�+(!�� ﴌ�|Lbp]�������_��$����i��7����M|�z�����zo/6�x|�:%���%P'v5C�D�.�\�j p�ߜܖI�m�2�N���w/v�����m��ȕ��٬���ԀYX+.c����>f<`N�l�i�!��V��\g�G��Ď�Q�3��0�ތ�:�#������^���� �Y�\T�n�".EV�$�v(Ӓ+��"�="�� ��u����rw�;OlG��P4m���ܔ��lT�3z�y�v�#ӊ�G�&�\d�<��Uz�>{�������>��=�h�R-d�vz[y陂�
,*�
��Dnrނפ�^?�~%[�:��@��^��9�mL�K[�~�}ѐVz��S=�Ȍ��������=�?����S\l��0���-��z^s0��	�<�0[��[�(ԫ��a����ϗ����>�'�6\,i
���}�
Ä���܋ה�ż�7�{�\��a�9G�<HkȖA]neP7�9Ll0��f�ֲa�	�v���В@ȑ�}D!�$�t�̧E4=w0{�f�����������!�p�r�^Ɩ���˛�g3q%���KE�18�veNwr�9o�xϳ;�;T���&��)!�:9�� ��;.�}[���Y.D+n8~AĂsf����$>�nG�OQ�0��d��.���У���rm��M��]� U��4#�σ�r[7�E��Q�WN�,!F�`�O�� �Y��#�t�@�U&k��-�K�P����<�8S-���_���i�nSƧ�����Y;\R�'6��5�%8	�h�"r��Zג8�ϊ� Jp��ao�^[��0"�p�4?�hiڡGDҩ҆(�O(�ul޺z�J���=ҩ��h�@ԴMy7fl��%v_<��O��R�#��7\r��m�N}"�W�ɧ��0gP���+ �n�ʥ�q�3��Y\~��rZ;��=!�1$�޳�;E42�# �Өd����!���ZD͆�Nm�8+���@�}�!%��Ɛ; �7L���|Z�}h��e��3��l*R�W��q� �] �7_oDϧ�w��-P�o����[޳��usU��$�LS��_$��,�����6�O�=)7λ��ٕ�j�    6�,�<_�$�O֣jM�)S�C�(ؕ��.��Z �D���I�i��n1����M�P��X���S�b)Y�.Y��ëĻ��5�p�����_A�EzDd�([����@��j�Q���d!�E (^t��L�u��:0�~Z/?Ak�T?p�`0q��f��yi��;���37G�M�G��gvm��dvk��A�Q�f��jfה���;O�)����c:8��v��(8�>E��x�w����2O�,� =(n���N䄎���u�:�����:����c)�$q��N:�Иj�KD�[\z��N�˱P����rU��d���͢ѮYC�I�1���Sd��X$S�t�܅uZ�9:��	���kq;���\��>��o���|;��ݳ��A@�������x���4�G9O-=��ZqGtn#���O$�c*��RL�x.����Ҵ.�zեp1v��9cD&6	Z�o����͙b�ͻ�<�ϰ0q��&T��Bۣ߁.x����%����U��)���%��]��C��\��F�I�b�c	[���'�P��K��z���u��`q��E,?�� ���?7�+�L�R�l���J9�h$/��Ԟ��jb��1�+���׵iU�7�HO�vO%���oߺ�M����e�(�����KO�:ȋ��!%|�D�v��*����
ѡC_�`�KΥ2<kvRa/]��`*���!���#&��2f����ýFO����� �һ��ZЃ�C�I�y낉��^��q��ѩl�Uxy,�^"����C�$�x(?��-	[���5`�tDpj�0����#Mb��� � N�J��Э,����"f�c!��Μ�=�aj>4O<ٻ�:�N-(�昩���z0���Nd�w��PGwuhk"ށx��Q�;�g��L����<�(�{m3��Tq���J���a`�P�Z ޠ�1ϔ[gdUc�,���2�P�yFZUzX��<����M��E)hS���;�K�p2�{�y^��(��KV�v $��5�k������PU���ʡ�"ׅ�c��l)�G�j�P���?�����#� ��,8S2�u�H���σ7�?�zn�.������O�w�>�������V��S��U��z^OIg�<J̭����3�A����;EE����FX�[���&6��p�@z�H{�z%*o��;�hj���I��Ff����H?O�]�%�bP�� l���˱MI�q[IzZ�]�q\zL�{����:'I@�Uɀ$��b#d��7<4&�ٚ�%h�J@V�F�D�!�-P0ՎQ\W�MT�NJ� l�/* � �C��_h�ֱ���㊉$u�����n����n���{O4[��B˫�
��?&��<P`A��ﮐ7�X)�n��+oG�<Yy,H�F7a�O����fxw
���#qC�Qo���H�"O��R���	���1J��"��I��}:�}�.����a�5 S ހua�P�ܝV�2O��*ϋӈ�̼��BZ,"��Fo�w�X>��,����<�U���L[����̀r�%��\/��~�4��/��l��5!
��@��O�,.؈oS���D�g�6$�'�̙G)��,MD��:X ���%�ϊ�9�Og	nh]p�\�5]���*0-rp5���M�J����E�C����I|w�ܭ}t�D�`���v��5�w�&z�:HJ���uN1)S>W֠"\��]	�b"��;~R�[�V*�W��7q�\Qy-}?E}W�Ͼ.��x|x��7��p%$r�;F}n���=}6<��#�2������5ǖ�el��<��[���K��-�i9_�G.��ªS7�S_l��l����eIv�C4'��(d-ʃs��D�(��"�6mW~/#��E`'b�=&�D�LA��*��pq��`q�Ľ,�UR
<�C*y�w������4D�K)�q��RJ��@)�U�]yq�»���x����n鈕=J*e-[ ��qO:K/�z50�pp�,v��8��
?���w�YJA�q_�/,��۵���M4���L34��0���zw����q����c��KK�w�*�\|�nheΪʜh�à���ۻ����m.�y��/{LX�ێ5����&���y��f����kf����-əž�����	<���X�H�/E�]c��cY��j�a���򹞚q�E�z��>6���Vl0�#)ʊEpBT�M�����e�I7��qVUF7q�f)b�M'���0��Cu`�Va�MO�ǥ�!�R�#{�v���w9p0�L-a��3���&v�t�(��fF��vV/~�ͭ��jtN!�.-%5P��!�:ϴ�Y6�G�^�)����O^Y6�f�%�7r���p=�[�MK�G���'���C���-b.�
y�����E��偑pI��_�?[Nƽ77C\�Ul+��U�"���8��rD��6Rp䦬-D���w����� Qgf�6W|�G���Q G�Q_���L��E��2���c�)���p�D������i\!Z{*)�y ����%Be���jg�a􆧍J��IQ�S�u�1(M1��^��cZ{�۷V�XW�ѴO��,#��8J�TQ��N��]m�p(a9�	���F�A�Q�h}���[z���eҀO�?e�8���5`Qc*^�0��k3��(���O����ZU����"d������΁�S��]_�X;�A�ZkE�i���0�P���R+��ơg����Ň�6/�8ES���H�X3/{~�qaA��˩��:e��(�D�,0לx$_2"������=��͋�K
v1.�i�)ݛ$(�B���9Ɇ��!�����U�aS�(��6DĿ��[�H��"R[#:؜�����X8�a�=(�S�_F�Z�#&��Ŵ֓5O\e�Ғ�AL��dZ%MFO+ou~�{�LB��&"d}Oj�!W�.�<�������HYK!
�����A����b+#ߋ��e]�3$>f�H��P9C���g�e�{[-R�Pe��o�M~�s�
U3�i16*;�DzoL:���cq�ë�>
1'�Υ*��������4�>;���)j+{��g�o�(���~��EK狶]�p"	ñ��/�]���&�=-�EY���ļ�'w�3sŜ�-3�������ѴE|�=p�J��i�m�k�(��?e�v���^qn���
̍���{_��87�k����c��٪��/�5�j�iZ�,waa!g��Cx|vZ;GV�'����H��c{z���E�����@һh������g�g�)g�hh��oۍ?6 ���vqq,o�xZs:�r>�������+z�e2r:�G�V|���`��~g�o���� 8̱�q�V����Q��#��W	%DC���3�g�3sLYj�q�I��6
�)��D�"�U4XZ��|��iQM[獸��=�x�4���Be�i��8.��sy� ��F�~��-Eo�������+�8�:+�X�h���gG�j1�ӊ{I��1;km2~Y&q��N������Ȯ����r��P{�" y3�����@[�Q{�<�c5�v�@�!
���M�����"���1wa������; ʎ�+�\}đ�Y��y7�p����Wv�;�c]�Vfh�ɞmZ�!EQ��`��\ �q6��]�9�s�&9�@�gp�!�Q|��As��Zu� [��YЍ���>�p���3}�_3�W���s���b��Iُ�^�p#���g�;-ԌT�t��B_�E>)|]�b�A���֑�wu�:�ɖ�=������-ZQ"�	�PO��P�.~ڊ�,6���1 Ͷ��NQ׋"�D���b�x�ܽ���[͙�B�߮;ZN.���>.�E�a�*�Ls�}�Ń�N:Rd�Q�f�GzF�K'����y�<��ŜYo��J/_Z�H��y鏩��\�q�����7�p����B_$EJM�d�B�Q7s,7��s�H���e8+�Dc��2��Ysa��� �   �',�������vj�~<��D�#1v2~�ݨ�j͸2��a����b.�D�T�����M%�Z<h,�E��K<�=������I)'��l=��Y����^$���^v{�Dgf!8��«Q����ޭv1��V����`���ᰈ����%��      �   
   x���          M   a   x���v
Q���Wȭ�M-��I�K/MLO-V��K�M�Q�L�Ts�	uV�Pw�K��,�P�Q0Դ��$Q�GjRQj9P���S�r󀚍���� �7�      �   
   x���          �   
   x���          �      x�̽[� 9�������Zr\4މ}����TV�+ҳR���hhg��J��H�~it��")���䠻2�*}@:�F��g?��럮�~��Ͽ���?�����z�������O��?����_���/�������������?��ǿ�����?�_���������O���O��_�������O_�d҇�������O���!�q~��P�7J�����'�}�����/�����}ڴ[i�-��E��f�ڒAksj�-��֖V����Q�8Ҷ��hqoׯ?����^�Bb�J����.j�z��Y�q�J���嫜��8����J�GG���~�-�)�}qQ��}��i_Y^��ŒD`q��*M{���E�W�-�����o��/m���λ����t��"돼%�-�����mQA��_��?�_��d]����j�O�}��G���&�>�޶�BJ� $�H��R%��B������N-�?���)���g[󇯿��Cr�##dq);���)S�%H21��Qh{>.��87j�)�√8Hj=�;���弟��U!>9��uY�U��ٸL�H�O���_���fU��J��pn�����C��jp,"���m�1%��������܉���w�?�m��(����������ǟ�������r����ɟ�u�}����1)�R��Ϯ��� �1e	r)�o)�!X~v��!gd�>����EV�W�m��A�~ ["�U�7��{�ʳTOK�����JXF	l�����[Mȝ��~QdR��|�����q��_�������"X�ޫ��ߩ+/U�y�����{��E��F�n��}�ncn��/��`�#!��9 Nc϶��a4�T��Jn!qϱ�\��2?���6�<A��϶}m�ɡ����I���f{���?�_�?p�s��U�	�)��de�^�m��|�ϝ��Ԥ���[į�
�KB\5�Q*�s_~ϒl��C�CM\�������%�%��w��󆌒��kϫ*����������2���~���������{k��*������c9T��|X�Ϛ��a�`!��s��ӟH�j�Q��������o�_�I��u�#lg�G�r@��������w�(}o[�̷��w���m��y���6���Y.�ʿ����]m��{�H9�[V �������X"���i� Q���@���,i��
�y.W`B��I���f�BD~8�Z-�׬⮏����y������w���������T��z��"���B*�f%�D����D��������/T%D�����7�D[��|��D��O���Z��D����]q�{8���{��|�:�����.+�٪�W��8W�A���z�.Vu�s���/GU�{��7u��z�Ig�����9ͥ�ü����[�q)�9%��@G}����+q�=�҉����B|w�j�F���� ���(Wkj����^NY[����J�[�Q�[7')��5[Kֆ�K.Uׂ�r3�'&mx��Mp���Ж�k��xi~�c���K$��ŗ]�'0�ȴL��f'��O=M�L��v^n��@R�A���W󗾣X�QU�E��6m�����dI3�c	��TͰ�5��ݿ|+mx^�ۜ��j��o��?�w@4�����!�����"��;�+v����r;� ~��4�2�Xm��,3��~>����a`g��4�#�@R�����>��`�[���;),�d���7B\7Σ��$V�,\�Q+m�<�����e��6�W�J�fH�u�<�9�}m6�hmqQ�������"��Q�"%���:|��7�B�Nb��R:>�d�����9��k/蘛�)2��".
�����FSX�#HQ�xޗ��]��3R\�G�9�ɒ�.?rR[{݇��ON>��HB����n���}���Z�9e
mV1����~OI����hR@K��02��?���H�c#	..��i������׭�Ec�[�!~�=���}���6�FȊ:�PÈ�_�k�w��W��WK9��B\[�����N�,����H�mV����d�����ߟ����5ݕ�����gu^�kC�#yk���3�5�����V�s�2Ϡ�8B��j,�����
na�� o�j~w��Fh�A������iw#�L�ˋ{VWss_��e���&��Hoq틃fqn)��A�� �uݷl��3&q�`��eVm�f�A�+o����9����fxS�^�q�#gj�s~��.��� ׬~6�y[S��M7K���\-�m�aL-cFℴ��7�f~�ו�o]�4ޜW�F���+�������U�~�5�z���tm��%����U=��� ���\ӆI亶��Ihk�
���>�鿘��WK5�xV���B3n�=�P���7�B!r�P��8ܡFZ��n�N�z�N��,[�V[>Ih��Mq�2�Vi|$W�+�C����;e��:=�l!��2��!k�S8�������[j�\��.�3�H�;T�H��Y�c�����b��XL�e���$�uO��Pzz�:<����G�ZM7�|qq.3�n'�%I�d���d�����T�B;����&�#���#o>.�?o��qJ�H�zQ����=l|B��G0y(�G�$E�}&0���eCuQV�ʭK��z9�\�A1���Ҧ��0w�άT�^�%��(��/q.�5��kft��Bp��sg�c����<џ�p���:6�yiP� �}BdNz�F�w$_��`�ŜZ���a�r��G�ph>vjᔞWv5m�H%��e�oiƹ�p:�2�J%�79�8�q������<��)��-�MQ�,��|�K�JJ�����	C����RC�5����9L����E��I:��U�<|��9D��s��c�'��tm8�f ��I��lt�*p��6��wҶ�xL���tY�p�fnԶ��M,�*3����Yz���'��4^��J�]�;�L�\��f�C��U`eG�z�8��!E�3p�.š���״��:쪷��"�������U>)Wi)cJi8-�|�AK�0�^)a8?�B�ޣfS}��q�� �=^�;����ĥB	�;
�R!����ϯ?�-D��%?��D<Z��0�4�P�*�D}}1	Cڜݭ�P2@�гz�F������ۤ�}���$�d���΁�ï���[O�J��e:�0t�A��?������_��7�o��������q¨�Y$�ھ��vV�jp*���꾂w���E�ި�!t�!D�yw<j�Ԉ��k�<�Z5m���_�x�%����l�|ev��-�v��dZo��*����X�0M5-���L��R��1ͯQ�4m�|�ɥ�T�+��'�;�||W|}�`�̓���ӛXZh�븦-��a�GL����¯���?����^�q�e�Y,�d9(|�~�����7���c�������״��j%�=s2���a^���ݟ�7#e���F�<��{��u:�������s��e��3������G��sկ�5D|���=I̻�ܾJ�Ie\�̿|/�D�4f���B�XjSc��C�ʸ]e�	Eo�2���ժa؇G(�_�����$�q��f���\�|l�z�-���@���w�ʓ�,ury`�mx����Y�Væ����sD7�O:G��Ԥ�v�}4��!=18T�-�d8����L�(�x}ݼօ�>����;��G2�t/��[�NBa�4�⻻#�g��V=2���arp�}�svT�K.�۽|��,[h��T�Z�R�J:tU9o�)�|T;'r�W�e�DGs�W$�'}��B�����-�z�t�9K\��ԁ�^B{6n�\��;o#�F��̮����-��Q��z6��'6�yހ|>��[\^M9nF�	�/DK����}Ih�f)����?���B�l
�A�ӑ�סi��(޷~�D���L���W���w�	*�-e�ȑߦ	K�V|�H�q��/^�a�0Q���9OK�Y�W�����G�/3��4�+�2�z�cɆm}���\Oz*������2�2��j˔��&V�2�����Mhp_���    7�F*s��k
��%�M+���h:ޑ���i��j>U�܀�!j:X@�{�h�/?X����΢�ͺ�zh5��5��hBO���$�i4�2W��bJ��2W���˔A�*�(-��#%t��r8RN�G��{��L~�R�.���Z5������f���S�v�f)3�2]��2�R&?���k�0�v?�^V��&vLE7,\��7��L%�d�T�cZ	Yը��q�j9���롐��mpO����GTkV=-�s4uyZY��|;̰�z����`��"ڼ��r��M�@.�y�c��珲V��;��D5��^��C6��|Bk�Ѹ�<��ᛟP�L.L7j���YQ����dnA��7�\�hB/̣�*h{Z����*��x����:�J���]��];��{r*T"�o���2uX��#d��)�hZ�ʴ��5M�.�*�9�St��2�b45�,��'�o�S?�b@K]�f9���#�q�Ҡ�����75߼=Q�[7�ݑ=ĕ@��²��|�\��[�]m?����`H�Gl�۷���ɻ�͇���8��cwI�|�����4o:9j����s�=L�����E���變��	��@�yהM�+�u7l��t}�&!W/v�+�n|6�^>J���{4w�6b,�U�a���y�X������c��.�JSN)o��Б*�q{ �"�L[(Ʒ�~��Gx��ۋÓ�t�٬0ms^�o��l�s��v��W]�,M=����m�NE+�\���m�e�O;�5Q�R��p�t�urE��G����2�tX��nK�v�Q���ir��wK�2�'�[{�*l����Um�I��t��S�æEU�
VF��[&>�Y+���^�ۈ�#CSO����W���'��-��ȓEc�.����*M��B[�$r�6���G<��s��F�lDK��f��&�6��f�d�׏�ݎu�du���ֹ̼`��B��8����^�.A�?pZ"�[��/_����E���[v��Nh��De� �E/��jm�N�ZѹR�!�1<�L�&q���e�jW�B��Hޮ�X���s�b[�&b�Փ8�B�&L�>�Z�B#�0�2�ƻc��T�*޾�$�B\�b�$��8�m�Ը҆a����a�t�I�b9�Lʤ��J[�\ �ڜ��6~ @kK+i�^�����B�Z��b �f)���sB\�[��#����#'�Nז����K�ӢV�Jô��������6y�[�n�"��ˡd� ��j�����$��]�Jq�-an Fq.��i���Km5��ڨ-�3Wr�|}Z�B\�#���N��,bڬz���܏�����B�0�׃����dm�ڸEt*'�sԴ����������/�DIH��ᧇ/q%�3h��;����emR\��~r�Ȋ��qUc^6'qެ�a�dN�Z���j�-���\�����78q�j��z�N넶�o��÷8�I&Ui����X���Ԛ�Ǚ�em�\k0-'���믳A��mC�iq6�@���}������ "�y�'g�����M����8_��D�YjC�~i��]��֐�g�E�EZlzྉ~�UK�=��a��\�~��E@�Zg1�9i�}�ضl�%��ԑNW�V���)Ŵ���W�����ε�ߵ.����[��a��N�-�/�cC�GP��[�#T���dC���i� �(V��ɒ���nKXXu0"�����ա;��^7"Zl���3$+n�{,�{��ВUڔǒ�/}�2E�
�A�2Ą�1���;�v;Rd��a�|�X@�<�#���.���/PE�%BBk���wr�fB�n������?�b�a�Z<t������ݮ�L�akd��d8W�'9 B��%I��]������o('��O�֏{6�N��n�6v%�3�Qf0�W���<���wy#�	��S1va9�;��+������\����5��Ʃ$K���Es�A�k�^��7I��w�Q[� ��e�p�R^�7͡�����0��ծ^^#��@�� 3�V;SR!3�8q7�2��n9�p�$���c�n���b&�Maq �{��ix8�H�⑑$cV2m,Q�	�)�#a��d���v>�i��{��N�i%���M���m�+�9��ЕJn�}g��!C۩{󤏼�X����׍����+'T��ҔۍtD�@J9e�g\�����R;��/j�Q}�\{������B�j_kT��D��.N��Y\� ~/5���c ������&�����8=j3K��,`�J�!s���������{��	;#%M����RzV?���t�~��0��a�K���kG0����0u�3g�Ձ���^���B�8Lu�̝Yi�o�y��ׁ=�B�y��J\D�_:�JPq��0jsiQ�C�MI����CDBOlE
��!��{X��x!��z�1��z�J�E��*q9�]:��׿=Z�+fe����E\d���z"Y6�D��jP���̇�8�`B���s�Y�p�ʈJ=r'�%������N9�u/�&�1�W�xO�8L����bx�a�k#=�3<!L�>��t\������b�k~���fD���߹����@�` �����Wڪ�@9�69���^y��/�Z����D��v�������h�����ҿ���Qb'=��/N��M�	����D:�\\����$�is�9=�;�#���o?��f�� �J������J��kx�`�(!��Ϧ�6��ھ��.v����$�w�z��*v�N:2�{�KK@_'��"-��Ł_�_��J��-Z�O4!�ž�A�k�L���\"��6�-x&���t��W&��{��0gJ�-��Iĸ��.? ��
�~ZǷ���W�#8��s?p�0�6nph��P�)AGxm���J�:?�.�&G��������_���y��mV�q�:RsPG�w��_�8m�,�s�3H�Q=�X�>:�"Z��#��J�k�ٵ&;�Lt1�]��w�$�F��:ʹdU4�^=|5T:Lx�/۽�sk�=��$.u�w�0 v���l��;b��N�ɶ�}��@��)�L�F=�C�Ǜ���@t��g�Ɉ�a��;T����ܶ`���Jq%�W��#�ǰl|w1�_Af%�/��`3rf���a��>����c�z�28�,��Q�^ʹK��1��,����KHwu���)I�g���m4m����	4{����.�`g��I�KD�V��	�mΖ��z�ʸRɵ��d�iF↖��7JS��(��k�:�X*�7��C�6o2�p�n�S��͵@y׮2� 7��4�r�L�,�S��)0��#.��=GI_�0?��<����q;�N����_ea�˭�=��|�j�a{�YxPYH��L윮��	Z�[8�p����nP��+�����@)��Iaff�5�'��4�XV��:����*E��ML��T��a|$g���kǅ�N����P�9&�d��o_.7���Z���m>��pxڵ}�v/r=/��
������gO�Ok��N�	30.���o�����*-W�X�>H]䜿�٦�b�����1����^O���Ŧ�J��:'C�a�S�Mϗ�F56Wi��y-����P9Q{��r���)*���=h��e��#L�ǉڳ�G\6.�L�˨ͯ�a�\Ffό�ӵ'���>��Zӄ�_�4N�0~�&�˪n�P��0��g���_iB�}!��P�N�+m���B\�	��)/_�[��o����&���"Ǝ�T�P!$X=�"��H���NB��&��NB��&dV�t�*QR��Bt�եi6D��iB��ҋ�	g�	A"��͟`��5�KKq�;)H�L�	��N��с&�'Q�]�z�r�d;��=j�n	>���t ����%MN�T�	�_�~_�U����qq m^\�L�&ގ7��P�&�F�b{�	�3��
K�=���2�x
��H���hGx����o_� _�i
(�$}`
��i�d������մ��_ZK�QG
�M���_\G
�w�K�:�ǠÜ蟭{�+Vp�B�i���$02^�O�&    ��ެpTw�Ez|-�"\BG�Ӊ����oC;(�B�7�՛V���ۜ�HhO'
���,N�Q}������'�]��(�k�H����(�qG��79p)�g����o6'ɋ�)��68���>9���Q���)gD�ۤb���0��M"����� ��8D�m�C
n��(�'S�����R�1[P!���$�q���?�b���B��9�IFiE%�h7�py���\_O�D\����������Fװ���Ұ<�G:���Ih&pM �hjݍ��)*+�#�Iܩ�g�:�f��h��N�XT6R:c?t���B<Lu�Ae�ʂM����A�Te4���Rctܳ���ԥ�T������7��Pm�����9�v���u��"�,��ͣ�iI�G��i�%P�ﱼ:�y�Lo���ViW�]3��ዩ�-z�����Hj��~�Щc"�о[�'�|lE�i���>13KN��_�l�P��T�o��U�Y�t>쇔FI쌒��Swh��G!Qm�{�b�)�_9�#�ɳn�vY�Q递P�c�A���Ȋ�Q\SJ�Lz����v�T�J+��-1��&*p��`A���'q%����䓐�c9�(�Q2��q�6�)�o� ����B���Y��<��{��@+��1Z��lĸ���K�K9��#�A�뻘6��<o���=O���FL	{�=\	�a�8�cJf�����%m�u1%�#�]�ee6u.,��!*C��$�!�a���*�ΐ��{��kWs`ˇ�� t�0"v���o�˃��r���CW����r�M)�%��@=T�J[D�E;��'��%��BZ��j�-�)�b�A�gJB���y	*� A/�����?����^�vQ�LTl
�>�׏�qg��a��g��ZtT	zIdqK�Gx/_�$ntV� Nh:��?�|5rZ;��Zia���yɶ2�Fn@D�K/��5�E��ZQ%RaG��(���D���Ȩ9��HL+�^�HV8����2J4���L��Ņ�8��������$x蓢�@%]Kw��k$o>r�/�����o�|�݂��wp�����"~��*�a�Lj����%��"�wKqh�h��m���s����EH�����.%hpW�y����F]5��:�I�ɶH�a�O����@�Ei�ڀ��+m�N�$]�j>pf��菍�I�´�Y�F�I~Jgm�3�K�ê��4�\^OA�em�<:#y#a5찍�UɈ�-������4|s�B�Ҽ���A;a�]< S�C�mh�g�2��p�+I��@�@�ՋlZ���j�+mpӥ���F��Sf/���q��k6�D��l49�i�-�1��`0���*[����|Mphm��ͽ��6����_��7�6~ qa%Ncz�8��pmC�M�A��S��9ٚ�8E�����I �t��RR�L���A�����k����nٹ�?��3WO�؋kj�����߆'颭�dZL9�茘�3�%�~Ү�!��[������tPT&��M�sg;�c�)"��]�.�c�+�(�"�%��������:�#x��
��c����V�1X.V2�=��%C�s4�rR�a.���Yg���m�f�@�H>����J0�r��+th��/=L�(�'s ͛s��φ�s�fB�����ކ[�d��s��B�	�3�>֑�u�a9h����*������Θ���cpܾ�gh�$3䌥�d��n��	9�hn���^��%̥>��m�Yq�t��8ӹ&v�v`J�;eG����t	R�O�;��[m�c�և�ձ���1%����*�0drԬ̮���M���6,�:���渮M�m��̻O���rJ����6Pp2ܝ�HƇ�����w�Awd��84�$��:���ɋ���8iWŖ
9���r�x�F���>](��R�����mX`�ySxB��|�?�:
��\k
��OlG�k�M*��,��î�8
k��G��so~dDmǑн��J��BS�Re,'GÉ�үT�NY�~,���VzB�p��G��.�u��V�����2aGj
��(��M�8�Ŭ�S>=QS�B[����}�O���mS��i8�?#b����~|�/p倭ۜb��gqvW+�t�Ty͌��W6�5�f���q�-�g�z����k�|�{�B[#o���h��`��V�M ,0&���!��N��a.�pS��Dl� ���}�C���.�D��� 9Cj%N�ŝ�o3 ��.')I�h ���$W������Es��?�딃���J��Ю�h������Y��Z�|�M\ە�g����Y>/R�^��NK�AD�K\󼦕8<<�z��|��*��jᲂӃ����~��4xLA��=n�Vk:^���������������;���0��әK~p���Ф>�$Ϫ�&r��w���7T`u��7K��0�!�wY�#q-�a���q�����e�|6����0�w6�V�$��6~���N/�k�^���8t ��Ǖ8���EqM�@��/�n��r�z�C��̟���h�i_Z������G :�T�9�!�K?�U|rH޴� � LϖQ�� ���k���A��D=)V�@`@�3ť6t��E��z��p�#fD?�:r����XB�8�P>���Z��z�A[�8|�M�A奔%!��+�L����h�����^���5��i���w$ע���$Ή��Z�b-�BN�97�2�A�>����rI�Xs	l1b6�v��&�N�
�_3�34F��v���07]���-cŎ����P��9�|y�t�j��p����V2]��.�t���9_rS��}_CP����L�y�o���2�vFd
[D��꫷����n��*��Y�9h�(�2�̨k�:2%�L��Zv������}n�]�v�k��a�"���ĕ˺<q$s�� F���.TX$�|��l��ۻ�},g�$3���a�M���?�Xhx�Iy+g.�7e�[`��Sxq�yF�&�K��=�ydU~
`�I�%�4_��B`��ۨÆ�����B"�h�	9U��C'��"�b�i7�C%c4�R"�A��}<]Z�4춢����bMJ��5�"�L�Ny����|��e8	��l��Acf�D3w'�d�B�j(�ř�L~[�9
��)p���p��6T�Y�2�I�(�|߬���C~B+O.�筇e�;���K�M���u���r�5�^y�#�b̻��v�-_�
����>�g_l�WBf��0.'�u��o�w����rF.�2�����^ � Z��$�G�&3
����^�]뀡	+�uM7��%�Ge}!U�U��#d��14#zwt��lU����,X����zT���>�r�D8����/c٘�4��0���E�A�z�^?����r��fo0ť��os���@di�j��b��}A��ΏmNk��\�X����|�������#߁U�@�_�J���V�/u�FL}���*JH�D�E�^J��p/#��Q%a�ǌi�d�P��k�H�	�%��<rN�k��fgl�J�{x�BӑZ��T5�!�%��j���N'9����bଂ��u߄-�Oj�(�N-�/Ջ��Z��J�G�Z�䮵8xw���$�uj	^���Zm�0T�A���j���ԫn�0w`s3tI�����]4wu�ġ��k%����E�a�� xo���ȁ[�޼�PNk���G.���M��ýi�
���|v�k�35c�7��-�%�����ֱ%	���/Ͽ�-!���e��ܒ�h%@[B� BIl[��М�%r��~��gU�����$	o�/�/GΣ݇9����D�P��Y"y�4pK��*:�fmu�2���a���+�}}S�Tw��IfG�h��+I�J�T�����5SbK�#�Y��R�W���6܎Hj	:!yBZj���w�Am�ml��>7���l�����iB$�ҡ%
���V=ĒƷ��jN�Ӏ\=�X8    j�6l$�n�Η��M,i��u�ՙ7ۢ��7��ĩtd	~�H�"�T�U�y9��Gm]A�^�8Lw��9�R�v5�������Y\]s7�^枷��}:b-�Ot�bG .�^#D�/�L����4�W�"b������3-Q/�e.�B���6��{�r2={s�cpdjA��ig�̰��U���<�bV~k
���L�@��@������ϲ�2/ �RZ�,ߠ{�$*�E �Tx����o}��Xo�<��6�=����b\U����d���ܾ��j���� �x�j�E�^��Ĭ�擺�珔��n�Kh[�S��QA���$�r��\7�SS��i;E=?o�̋��� �S�"��v΋P���+pK��V�N�5:$?EP l���\ح�#��Ᏻ�g�BwgGqYos�A%9���A��Om��%��~��O>:1r�)�V�g��@$�2��L���|{�7}9L��z�?�&������V F �jg4�~q�H5MO9��Tx���>��V�3�:��ӶG��;�.5)�k{��NQ�1]�1�HF�ֽq�5����pm�s
o��0$.���SX*'\J�$.E�	#M�� A$��D�W�4B�h8
Up�="��	�1�vT��͠�߼�M��VS��ꮉ�`f���5�<�M\��:ȷ��
�P��[���|okyŐDL1����$$v�;�A��ZԳv�;���tL8����0]�.n�#�+mxa\��13M���v�9���ڕ6xY��/�*xMЩ���;���&�����˂�:����@\\��?�8QC�]�����R����wQ���U@k��/�Œ���J|��L3�Q�C\�j+2$�q�Fԃ��-�nB\�"���+�I�6i�6���Z�M���o�6i7���R��(��|p��O5>-�i���t"���i�0�j�6-�\�.��7�}����OgH�[��]D}�����уQ�W�f�`c}=ri������~>移�y���ߌ�^���pm�B�����[�k}Ն�*	n�h�Dk�o۝pp����"�17���� '��NB�����F6G�i_���ڊ�Y�W�&����v�*�Wo-��68�;�%zǌB��Kx��Z81�|G����������pm�m��s�A4�����L*-'����L*�A�����ː���E<�~���pq���.���b��P���#�����Q�LR5�� zF�v~\B���ك^��*c����O�mҶf�ޕF��m@�i�x���gv�N�d�j��\ IA�Ů\M�Ү�����s���U_��u�<�zW����|
�9"��[~8������\.��O���J���r(~��2dK���~�?F;_�)j�F��D��5����}�I>�F�[+Z�ë��#yz={b}����:��nmŁ��@��7;���F����+���I?N����r��Q���y"�qGt�|o��4�/�̞��x�L�)bQi����v��<�&5�E1K�#�Ǉf)������֯73MW鋟<�l�b�wշ�'�O�������W����l���Ls�9�8]¥����'��;��&��UNO��wһ-�W��A�pVO9���Wr�VGYLjW\�|^��g���Iw�6j2{�GZ���t5��BM�Rf������Y.�ӐP�-�Aߤj��<�����؁P���7���*�|����W�513,q&F����$�5������2k�̆�r��:���N{�L]�%��w[N��bgTHT}��=�/^MZ��;f���|����(�zŖf���bN9�+y1��ۉ&s]�jw�y�I� �i�<b��U ��eWD]�y����&�r�K2Mٴ���s)c10�K/28�5��wTN�Z"n�9nH�/��P��_/c����L�Mޅ�h�����S%�Ĝ8_�6��M>��rBG��v�}����0��
�!FK��a���v�ϲ�y�}�[���<RGx�yn�����ʎ_�eq�>^�YX���?n�����Lkzƾ]�ˀ\�I�0�T)K8�ɋ��*}�rk������v���K�RѨ�*1�"U��N���\E�wR:�; tW�y.Wd��aX	�����2�1N<��1j�6�������vB���@�Gqk�נ+�"�.���|�+�U�����R�+6h���6��j���l�_%�S�K��cHqԻC���8j3ǻ�6L�Ѡmn����}!��щ!k���@E�B9jm!�� |��m8��&��n�i�Bb�=�Lw��y�M7\]���ش�;˼SN��rҷ󲰉�&����lr��%<� ʹ�.>��-Y��3i��KA�ؕ8�ɞqf9ppG�(q��ahg�9b$?/��J49�͖�C��е�����]#L0��D�{�i��^!������SOm	^�rW�+q�N���G��k�V�^�X�^C���_��������Z���\�|�Y��":�������7����Kq�^�)��!��-{//���͠w��z��|3�8�$��ƹRg�'��k�-�瓦GF2�E=ro���\���ME��p�dӇ�6���Oh8a��p����r��M��o\Q�6���t�C��j��q��aF6~w ����$a��7�ː�v�����k�$�#�I^�]�����fQ���ս����_o�jK�]u�X���>q"�4Bt�tIRxKHJ5-6���ȀR":[z�������ߌYjC�-��j�y�mRA�գ8	�`�pq^�k"Wjc�a$������؜���F� ����YbY�<�l���n���:�&�������z�;��z��L�N�Kn(a�`�*pGuV<)��-�J�]�5	_�[�0�{�x�.��O]��z�.НBG�,n	��\�M���3�]������3�뢱��Ma��s���a��]�����J%_�e�)T� ����&݅9S�[�����OrS��Hw�#�Hw�G*%��Sl;6�/�)\�����d|������L����g�+�$�$�R�b�,�%�d��P�
/��:�CW"�擦�ґ���Or9�x�]H�T�+���q�0�)䈩�r��\gF������px�A/��ݮ��H.�N���R�X��q(,?L~9���c�N���E��7q���B���vU�u�"ՔHs�ATr�rl���y�|T��)}����i��w�N-d��RV�6��{�o��"^�+��Fz�o��s��R�T�dZR��}�Y����������f'�'�b��B��dQ^{&�S�:�}7W+��F*4���W;��th�΁��m��L�{n�X�������/�#�)�X��7?#� ��i�9�K<^'�w����ܾ�[�����Ǟ��k{�̹�7�l\.��F��^����y�0T�ҝ�����RDK<՘ʖibI�]'�!fn^�ߺ����l�2R7'n�[�7 o�����'j����ph���g��)hm?��.Ę��	���	�"�.���
|�g�Fu�yj�-�����2b����6�)!�9��ғ@6�Q�,m ��a3bFm�QPO��k�oF�|��̉�^��̪PF5m8��Ct��։.�~��ӥ@���BcG�Py(-�R?�m�'�=w��N����|٪��þ�T����C�����e�a�)��\.��q�)�KID�`S��j��nS���lJ�'��6����O���w����R����\�4x�@g�䄍u�)�C�I�-��.�̑D~s�P��⬈$�Q	-�4sF�����=��0����N%t>�z j#�˽���pt*����(���
:�M���e>%���I���68��q�}J�]��@~�"�O	Y]��>%����r4*�7s��dTB��^�y����>�� ����ӱZ_���Q��@�C�c��)���K�]�uM�,��k����}J�c�e���S�������7�~�k��ů��ag���e���6�xz��r�j�sxz��]B�    �i�B��@��\@O�W	r�	��l.'����~�u��/oB[��9������`k݁� �\��yxn�"��n<�(��{�l��D<�֫k��ف��t�5M�\���A߃^lBm�hZڶ��W^�X}�bH������V�l�Mm}`�/;�<յ���GW7g$�:Wl�Ԫ4q*���*�,3��{���f�S<��+%6���@1�%?�s�pk���2ٻ2a�ʴ����b��v�g|������Ru���I�i~S���Ñ���;E����{Y���E�x��oVy�4�B��
\p�����_�;8K�e�e�P���3~�=";lاh\:,m��qH�+\�� �1u����YY�*7[�M����Z<"]z&w�dݫ�磜]�b�;FD�^$F$�<Kd�G����2t�~�m�4��n�*����S�+i�|no�-�1�}���1�"��a�O�J���y���t[���i��n)�g7>���"�l�UGi�͐k�p>,���I=��A�.q�t'��Ek��e���L�L�o�y�m�6_{x��9j]蚡U�k������������<��Iԗ�z2waUZS쓾r�b8 �cm��8����I��@$�g�a''r�f�C�o�(�ƒ��<ס٤�s�[��|�ɪ��t��	��h׳����Ucb���C݆���o
�������hQ�|�0�Ҁ�.�J����S<ݮ'�/�ڞg�9^�4^C��m�4�4C:�i����8�'��C�f�j4my�?Rc����� +��E��-����!�tph��o����;�{4�J$*��Y�s��ce�J�37�q��ǆ����aiH�wϺ'!�f&ݫ�Ջ��X�u��"���_��y��R�+�:��/�MN;�Q�|@�:^�[��K���t�P��eƱ<�J)e΍\�'��:s�����;��7�_N���XG����è�T�121	q�*�k�W!�1��&��'�A�YiK��Q#A�V�@u�#x"��i�_aD(m�.�d1u3�ZX�'��f�{��@' �Ӏ�x��)�Th�� ��T���b��o�.�`�	�I����=p���ۚ����/��x�HG=��$�w��#�����9u�^��#=/�Y��^`Z�Y��aKU��b<�M�#��߆U��`��兴n9B{S�kh�qgl��sl -G���F��8B�>/m���[���ԋH�k��V�.����@i�D��B\#��őh=�f,���og@����y��/�c�m8�;�AX�lDHka$����6�W��7B���ylv��<V�����O��Е�R������<�E&�Z�'�7|a�1�s���2_����zPW�VV�4�4i���T��'���v�����~������;��-Gy�h��{���;�L������u���ݭ�6;��
�$�i:�{�ԍs�~��oN4�V�"_�c��s{��VY�W������A�G�t�P-bݾl�X6��'��Y0.�\(�H.�Y~6%�Qg;��3�;���q5ݥ���#>V#mU����M�j���p�2J�6��z�tĴ�eN���{`IWF�?-��%��V���K�/�#�Z��cz����A�x3��n�l�ׄt�VWi�.���a���רKB�Fu_��ZV4���p�!T�W*�)���o����b[-��6�b��9��b�	s^�&�ō�c�l!Ԑ��r��T�S��S��8ic��$�X�����<�y�w��C���%��O�r 
O�9/�s�D��iق����ɇr�X�	��N��l�&��K�m�b�P��w!��.��eu���WB���� `B�mvގ��X3�X�\h^�@���w+����DM�R	9YW?����]5���t4�[켇TެujGl�54���s�w5����ѰZ��!���a��*�r��A���g�R~L�*=�F�}Y�F]j�H�nv���j�+���uN�rB�hk��Ѫ�H���wE[�Tp�h�Jcx���أ��4s�Us�4z��x7*垚�u�����E��-���ڏڗjƦ�\���Q���A� {�k/�E�{�������E��H�#��(kh��{iW��#gf!U�S���nL��ةy%/���┱��0cS�=�����C�Z\�T�n�~�Լ�ӝX�beW?sW��������(��~l��-D��2���&�w��\�b�U����\E桜=���kVY&9�>KVY{�nMw���Y�BB:B�j� �9�̱��Ȭ�H��tX��rʖ����ɦ��rc�O��^���U�ci�,R��J*x3u'���׍W��M��e��U��aW��T�x�;�D]�6��h�3����xvVB�ͻ�	[E�3{^ήz�M���i��/=���0�͞w��ʉ��&�ä́r'��[{��|w��z�2֛S����~r�^3�/�� T���%��1��� N%�O����	jD��L�Ю�1��j�HoV��b��,�深E��#�\3Z?�ݎ
����/p�v�紉O��y�~�޾'^DK������gszG�d:9�)����btv��s���峞�u׹G���y!��c@��?~6ү�\�-�0�
 A-Fӹ���sX��͚�6�k��qG��ښyZ���'�8�͡�ՌS*>���� z�/������V��k��[���Ͻ�ȎkQ�Nw��ν\"��B��*/Mbn�[_����Y�����˭V�o��@����M���ҤV�'�L�4���i�i�|_²�$^�B\sM�M{�e��5�4ܵw^n)�O�n�n�w�ċ�Qc�"	gIh�n�6
�qޛH��͙���ƋS�8�>98��"�#�-�pqڛ�88�㢴����}Ѳ�e���)�!�[����,ͶQK�-������	��������U��Z��v�9k5Z��;/|�����/3�h��ô=����;��,n�ZI���j{7���������/��-?���;���Rfy`��0���� n����2d�١���ˣyϹUt��5��b��L�\�ik����}'����ݴzF_w,��R�x�{�uj$?����1ͱ�� ���e4v��zՊQ57�����oN	h���p��I�^��o5�ʹ�f�����:t�Ȗ�Yߧ6���R��R��L�4�U�2V�H{w(�x~���|���+���ON-�ӌ��
��n��]�,�����JV�����ѩ��x���^e�R��o.9w�	kwP�� ��@��,���6�,2�Dj%D:[��E@N�Y��v��s��W*�	�Ti�lW�W��A����J��T�:�����͑�w��:ϫg��S�b�U��ň�[�'��X�w=�Bwovo�~��Q�hh&���yS��&S�8߼�oޔV�c�H��Ӊ��>5��ݡZ7�;;�1��_�rN�t;.�R�K~8z�����ֳ�v0���X�$ko�h�ayo����v�㨘��g���ޚV"�"aVj��R�9�+��� ���4�y MZ���=����׶��a�ͣ$^C�t�sC��G�co�ۑ��X�ʷ>gH���"]��Y�<Td,��x���H:N�t��������+���L"Q��W�ڦ��\��|�z�p�=���5�� ^14�4�
W ��Ӝ�b>�$�^�݅9�`�V0�K�S��щ�*�}�V:>{ߠ�ۑ`K�<�7�����j�}0ii-��V5o�as��1-���~Fbh�Lʺԥε�X��.v��87���J]N���w����$Z,r��X��"g(�����8K�j�m5ڣx��Ê�@7Xֶ�>��_�R;�[���S����^݌��Һ�R�MPl�y�Q��cY��xի��	�����z��$B�E�����kO����^� 8�����S]`©(5���`�˰Jn�����|�&/�V���K��T�>�7/#D��֞jV3Y�Ց@{�x�'d���5�DI5��+L�.�j�hi(u�v�����h�����w��|��o����i=_��W#�۲@ԏ]��D�O�/�%�ih4ԥѺ��]��R)�C>    ii��u��Jx� ɠ#ȗ�_� ��=�Az��w�\����^�hmo��vCß���c;,�>��9S���~����5��5�l"�J$_�pW{��#��t=gly-ޛ��:�~{7���>���=�1kd�1��RչZIbA)�d �B\7�c��� .G���Ӫ�WKFl��g��Zژ�zp��s�b��z7�����Ҧ�-�/�7���'p���$���Z�ఆ/U�7���������k̩�愴�8;�C�YA�)M�a�D���|3^a>��������\k�Mhq�[�D�߫֩݃���b=_�ږ�z���FmҚ�l� 0Ƞmƕ&j��lJ��T�1��K��]FP��q��c��-[M����3`�����s���S��=�y�]<R14F����>ƆI����GG.~�0&��Rd4<d^ߦ�XlZ�.1NÌ�����^�Kg�_y�+O��p�	���O�s��b��N�j���a�}?�������ўη{�$�1Z�j�w[��\p�-+�/ߝߚ��K��:�u]�c=5��Q�vT޽��p�V(��/�����V-0{�ۜ�Ė�~ŵ���6WѡU^m�O��ZZӋ�R�F5:��$������b4x��䚓h�5��"�9�sn��cn��N����N������f��Ė��<���*�SҪ�E��Jj�8�M��ywG��R�6�1���r���N7s9�֩U��v�k9�ݝ��;�A@wz�0�������;���ow�ǕJ_f���)E5�-����D��w,�A����='
wh�FK�ݜ��\c���Y:FV��t~�uG1������~���H�T��f��Zx�w�t*��)ePV�5�%�6��:����1��y|L��Q�m��_�Ǯ��=q�M�Q��E���w ;H���¶�a�jZz��6�����e�;ԳHn��\�8�v�1<ģ�P�!֍�%��o�C��}�MX+��g�����F�� 1�����s����v+�Z�$��2mw����8�L/�j�;�*��;��F�U��)��:�4O����9�;H_5�ܽL8@�nm�QP�^�*�u$�>���m�v���es������>/b�w������|���^E�6���>��ҏ=����0^=��5ʔ�)θ#U;#�R��.ƚ�珲��6c��Lm6�-j��������.g�]���v��L�/�Tj^��'�T�RY��v�l���AQҊ:���)����
\�\h|smB��w_`,���bhTmr�f1��s�J[���Y���{��Y�[!(�y��믻yywC�9�]��YN�jw�T��]�K��\Q��jߐ#��0�Y��b0MN��F$���zTY��7��Y�K�嚀�����q~{s��ɍ6��Ye���I����MiLE��j��?��>tQG���6a�7մAM��.�Z�\�w�$n�F�7B��RGS>�"�����r�@5����ݥ��"�DÉ�W9�&|�[�67�������������c{�_��|w�?�Е:E����l�~�K���^.��v�gZ�,mb�n8n[n�xI�Cw���ِ�������E�Tf�)�l1�v����Z?����y��x0_'̾;�&����p���{Mg��8X!�w���&���6�q�bN3|ش����Gr�������ߌv�m�f�T�"ڳ~^C}R�b�!_�$�׃�=r_�W������/��à���a������v�3f�F�ں�=p���yӭ��*M�:_���pb#���1&�UV���9�t��z�e6�ّ2��C)z+�\��7'-d��R��ґj�*.����{���+��\��G�u��h0�,d�j��W�Vڈ3�n�]�rC@�=����k�3_�| 7��ۉV�݆��
%�y=ߺ���R35[�O��s��hp��x���(� ����.�0��������o������Xұ����7|?P橽]}���W���> PcǱ/�t9���9/x��g맱��t9?�P,J׾<�]�"�\�)�]/ZJw���4׬GW�}��]�؊MB��q��˙�6���(<,�����\���k��y��6�Z}�8�H%�'�{����͂���-���q.�D���v�mX�y�����qQ�nN�\{��n��Be�7�m���y�JG7��OCz!���΂4���ֺf���oV�Gx�q޸946b�G�[iLO������G�P�wS͔����hl�����-/�s^>���F��4l~�4�}�x'�~���	Ǹ��z�ox��A8����P�+�Ʋ�g����r$�q��|���,�o��O}Cgۮ�z���^~���pS�	B��@�3`��7�s��M��^�ҁ]�҇^��዆��~cȻM�Rᆄ�Y7�m⋎�N��gj���_��6��$7~�N�?燽Ar��p��>�����\����i֘�R�z�O��XO���(��{�}�]��V��ِi�����EG��G8����l�<5��|�u�)�U_a.�pS�ܳ>�?�:پ|��=:/�g�����ג����|��²@�lP���KVA�a��q|�
0��@Ɠ�U#gr���Eɢ ���L���SA^9h��oQ/�����]qy�Q�)v�$7���F��o�f�qۨ�~��έ<zA��7���0�f��+�2��16+����$����S�vV?������7°����+���A)n�N��B�.�����Z�b�͈Z�(tA�Dտʊ��<�2)|�4ϵ�n	���_���Aa�����?~�Ͷ��Ȃ�l����n/��z%Ӌ�4J\����V�Ǯ��{:*t���E�����w���:���Y8��f�h/��σ�@��F�ޛ�Qި�s�`T����R���ez���R��������S��>u���I��یZ��0��I=z[����n�G�.)��� #���^�9H*^��й$5��W�͕����4�*�^���_Z�,��훻`I���S�����6�IG����<4Z�һ��<-�����pǼl��}�pi$������i�6~���y5ȑ덭�Ӫ���n�F��Z�ݦ���t6W꺳5��y7k|�h���߻6�qMR���Cx��mߘn�}�׼��ō�oYI�}���yV�����W��=o_�y�P���G{�q#.��|��aM3n�[�G�f�Y��*�|��*[l. c{���` ���x/D�ϲ��g]��`��m;awv��V,�eC���(M��Qk��6����߶��*k���������v���t�i@�GP������]�1n`�3)%�"/�Vc�5s��1����")�������Ӫ�1�"�4z����0�3�v86��;�y�F�-�||b��AG;���i�?)���<�팸�#�*���o�R�
��1�����D�u��K�wi/a�?¸}TҶ��ux��T�+W�5�� ��^6d.Л���F�^.H�rw~����M���ť?�xY��.wwwk%�����7���[dc�e�軍���Z�����e����h��+�$��/�T<��]���:b��Ɛ)Y��э�?�Ġ�61��|��痙��d���t��AZ��S�h��v�0����P�,��c�w��z�V�TӸ9�����������/RlU՛�o[��w��!��*P���};�I��|�����w9%�O~�W��>*��s��E0HW�^��6���@�^i���HH�v9�Ŋ7t�������knq�8s�f\�m�~���^��8H���^������8)���9��]��|>�1�ڷ��ݮ�5��	M]�q��������3�e�.^ֵ�Ud�����2%jw*��q��m���7�^��u`v\�%���46YO��m�i_�ݺ�zyB����-��|�9�l]>����d�2��Ƚ).��J�|�4�����ۘ�I�*�.����Pj=�v�_e�K�����gh�G�S�Uf*�Lc����ND��|�3�3��F~��DTNum��n���YMh2˵��v!Iɷ��ޡ�6���[�1�VOjUw���夢    %if��l`֩�-��5tɂ��K�&���=�n����*W�˩�X�O��de�f)��}N��{pp&G!Rvm7]f����n�a�y�=�����?�'�<���\�{0��W�[G��? p��n��}BAy�N�ȳ��]n&�5�@�³A��{lN��Ē��)�����e�a 6
曪P`?@A���4vŕʲ�*�m��{T���6v���h�N[������g��8�ġ}�Y\⺩m��D+�sL0�d�ĺ��T���8.��?��9]��Z;��n|����~��N��U����u>nF�X��u����K5i8̓.Y1hm!�NL�}ޡ�ƾ�����E�>�|���pVU�j0��)Ǳ[��Z&W �[�[���g��^�Tml�TL�9`F��t��1����}�f����1�����&7;ӌ��l�p;1rCp84���}����2�� �|����NrӞK�j�1ĆI���M>q���{ܺ6�q�;����]�v��翹��H�]��3q��F�''���8�����a��K�h���׏qW��ݡ��@Tw��΄0H�ncw�Z+��ب^�� .Gr0�笉�OXX6��/��rr��J��!nZ�����v�Oz�j�>�o��r���,�������T�S��if7k>�5������[\�؋���5��51'��Mu����������Ov��.�D[*��R���<lh�m�w��z��SoN���$��:���n^dr��Ѻ�����h5��1v\1o�3��̡\
���$�SL^⨙vr������f@��v���EFi!һ��H�^~��AjV*��0;H�JL��ӊṟ{pV�n=���S���ީ���S]'�����%�.2���Nx�;3��;L�` w��m9�{�b1O�2��n@PGuwYx�(ek�� Q���Y�������v ��7Y볜��M�>y������s ��rm=�|�^vj���//М�ly˶������H�m������K)��{�G�/���{b�f��|꽽|{�^ia���1���ɡu'��Ѥ�t���ya�Z��~�Σ)�;jX��"��G��!�G���.lî8e��L�>s�[�aF��MU�-��� o�K-	��L����HU�f[9k�v�^���U7wҨK���us^* ��0Ӓ)�-���t����9!�̇��{zE+�L�:���f(�<���L���qn�	��<��j.]��7�q�=V���|�f����~{���w�{�̽-���k����t)g3��k��`�>E|{&��#5�Q̸�t���"��s����R���_���WcY.��]���u�l�w�r��bs>�~�!���n�a\:��s�Z�1"b��������_P�"5�vw�����+�
�Q�YdZ:�xZg{�j�b�c%����2'�5X�.G�T%O�B�(ޛGri��&�^������:K޽H���aV*��A&�[�mV��c���\�� wo�K��%���� �4d,�]�e9�Xu3��w��&D�F/?�t_�64:��� ޻���Cl�%��)߸0�������:��X�qK��d�������F3���c3p���� UjE��$}Ui8@u���> �}�F}xo���>(>E���n?�~K�}��=�)�A�WQ�pjB��,"��c\6r�� ���s�g���\klzWqP7��r�gm�������~J��1Eڣ�x倎	�m`�H�8\[X:��9n�`p@c\v�I�q]��i .	m����F�P�lƅ$k*c��f|������%��t�?�Q~|u�{s��P�\�s/��e�w!*6����?��xn�:���N^"!δ����<Re��n3�k�J�?lƄg�͸��h'������]��Y���f���q��
im1D̎;|onՌ�%��ёڧ����Z��	D������ �z�Q6z�����؊�k�s�9]�hmo��6����['js@W���s����VX�s"ڜt����d�-�_�,!-���K��r�XA�]���ކZz��ɸ��&c׊����}�(KTw5Ϸ��U*'�t?�$k��O�=�����o�?{��]�6�ܦ6܍�C�x�^�,�YCG
ի۳��2���l{G�j�b,{�P��C^���#2��w���U1���q��qM�{zm��n<n �>�j,�i҅�,����^�>�G���k�Ny���v��'7�����Ck�l�ד~,��Nۮ��8��� <TC�i������?>�v�]��=�.*������?�.5���Z���C���ª��k��]������-�ݽ�����٘��[�˖Ӳ`�B����gD��rڗ
��$�C�'�9��3@쇹�������;.���y���C>��n�3B���.n֭�P�#W!�7���h@Mm������(��N����4��pQ03��}\�����l�1;����ݗ͔�c1�����.S6qis��kɅ\ۀ6��^�4��ͳ�hh����qD����4��Ozir/]@��R��Hi��H��l�����f�^p�H��Y��� 6ۗ�s5��p�EN���,ć�M��OC�Z���}c��J�,�wD'z%�:����y���%�p����F�^����c�i�����:T�n�.J"����T�C���-���pj���9.��ĸ��_�Ua;6.���T�߱}���f��m��kSv	�I\]k�b�}�z:����O`�`O�5d�u���JM"=W��ƘVC�k��rm�/�|v_Y����ޔ��/�!�9���?�k�N����f��k$�$�\�:���t���Wn�
j��-�7�c�i�X��(	/��t��$u�{b)�b�a���M�un30R��x�l*G�7�V%�4ÁV6t�S^]��~��i�M��O�J�W�*��n�J!�]��oŎ�-�B�6�k\E}?4@j��9I����>eICX==-M�$E�� B�r�ZԺ@�F�k��p:���t���d0���h��ٕ+�>�z�Ҷ��j$�+%�n���O{�ͅ�a�`e4p�|��o��K�'4@	�GP��t�Aw(X:�˳\<��/�8��,��_��I�"��p��I÷iɖ:�� ������V��� �ޠ!��?W@�۴�.-��=܉J��q��W�Љjgm�]L��(��9x-|܂��6m���y3�Mxˣ7�U�!����7{����f��#��9JŤ����c�F �?��d�q3�r��Y�\Z�co��g+���/�(��q>I���ۄV������u��S�:��;��4��|*��U�^�k����WR=��+L�]	�ܪd��m�w�Gyg��ڏ��c!�﮻�����.����$��J�}�������˪fV6�iY�/���ȭ�q�6����\���u�F���AT�rW���k�X�Y|��w����>�3�^H��m�p-���]W�7򩺤����?���ۿIT�'�͈Zk���r�V��ˆ������{YBjD	�Pŷ��tv��%�T����!KHI4d�u{&�*M\q!��H���;����wUz)�/�mZ�ZX���+�|ƞ4���.5����(�rWd!��f�޼�Q��-Z%ٲO�u��s߲cǍm�+����\�Ce��e)%�!e��N�n�g4��?hn2����qeMJv��� ���z��B��� �4+� ����('c����t]��<R5�ԛ�)����Y�EQ���,
���LU/񵷍� ����F��>����r�y��)��E��m�W��C*c�O�RpU\W��f�$|򰝡ZWJu��M�aݐH����4�$��C�!��4#7���q�⊄|9�)y�EB��M��������'o褑���y�y�0��4���}ȹ9�u���j��v�n��Nj�5��\���~g�RJ��|����)G���L�Wݏy[2�����J9���"O4���P�:CJ�
�7-���^�_�μ.��"	ӳ�X�+�    ��i1=�2���R;��KWd8#�D,�D�O��F��4��1'��uZ���37e�Q*cǊ%{~�^�/��c�����1Icl�=�R]���a��V�,�6O&������|V	��/�m;��V�xM���i��)���1^S�Z�$X{�R�\LaFb����d_-ws$�F�<M^\��XN֝E;	wD�f���� ZM֝���_���J&�@���}����J�9ek��圫+b/^<#pI^�Ƹ��(��i�7�I�l��QY#����p�qH�G��v�� �1ū���w������Y=�"�Om(c�g����嵃s�]Y.^�m_���!W��)CQj�����ֳrMQɣt���x��oQ��R�
6��(����p�//�F9��e��dm��m\-Ϗ(���:��$��9~<�Hoc&��j�4*�R��P�j
��m�RN�9��8������s��O��=zۨ�:�� �l:��l̋`f�M'��c��̑ɴ�z�z
�0�*J�a6��#L������COQ�Ζô3�:N��u�h[ȫaz7C-$B��G�<�L�P׭>�� ��3Ma��%|	'Q�	&w3��#�S������_�Bag���]Hɪ���Z]�n}n�$?V�	��8_.���u�0���"���C�W_n��7$�kz��Ӈg��m��>I�(����=C������u<�5/o[g,^H1+,M��3;@�>b�H'��3;��ƅf��p�E>@k�J>�#Llɤ�;����,���$f}q��)#Kҍ�Crԍُ���\�@N꼷�r%����qM�CC�,g\�x�����k�ڠ�C��S�Xz%kNB����OA���BGz���>��6B�Q��b��##��r�\�5E��ծ�f	Y�l��Y}�^��2v0���B2��)��6���bJ�\�Ȼ�앗̉|C��g� >	�j��0��xbfx�x�S|Y��	X_�ը?�o�ʥ-C3�y�}n�$��H���L7!p��a��"�R6�d�t;�QN;t��p ��������k�K��N�S�[<�]� ��� m���K�u��ߖ[��w���t�_�����bG�s�%��E �Z��3�?Q�h��D���;�,�G
��y�S���JW�U���_-#��I�!2)f��"�(��X������TixL"�`�T�E�L��qf�M����K5�7��!Ɵ�������Z��`�B�I'g��� ��X�Y�Q�9Ld`��˗+��#Jm�C�]��7��]���G}�:���MĄefj�%��Ba�-�\GD?skKv6JV"��f�����R1����#��T�bm�:�O�n�y�Z�]M�N��pZ��F�S#o&3p��w�L	̓Ǒ-�q�X햿z_�l[���2���v��ї�M�v�H�k���E��|չ;��,�#�|J�:�VS�#"��WB_k���j��c��9t�2ʉ�c���Ա<Jl����∲i5S�	�>�Y�R��Z�(�sՊ٣4�9���LFG��Nk;gS���/��~��2�Z��S���i�X>q c�b1����.��r'+�L9_}T�y$�:�2Ԝ�y��j��{�RA��剅��<*/���47�'2]	�lA.~U4l� J���@O���褟A2rkDD�9N�$�@��Ʉ�M��#t/a猹(&���LZ�d�I�Z����l)c�g��h��V��F�����|�Q[��l~,�����w�����;GO��dѮ\�kWRN�[$��{�L()��й��w9_ì��Z���K1�E{G�a��N�2<_}�ivK��Is��ǹ�ɉ�D7k�TT��9��V'�6PΚE�I���Ԋ'��!'����*�/��(����pzWk�2K��H�0nS�Q��]���̵���A�7��r�UFw\�n"�^Hr^�r>�4iO��[�ԋ�)�r	���F)��F�>�2F_/�3��0!��Q��͏��f3���:Ph"p*F3���4ݹ�!|m����0�p��)},���n����iz+	�e4m�N��ȭ/<ԁSQ=�iy���K0��":�w��<Me��1��������;B�]X2�� k�Cy7��h��:�`hz�������.eO�$O��	������T��Ư�ԉƢ�T�x���>~�~�~�߿<
��Ͱ�|yNX���)X�R5G*�:2N���&2�-,�c��C����ZI,�\ppwc��~]�ʺ>�~|�#���J��(ϫS�q�)���`IPw����h��3�7�'����o͞*X�P�l� 퓓�B�I�\���`3&\�_�P��*v�ӸCﺮ��%�s��~	h�ђ2�r'�8��"���wс�9�сBMpv�M��}N
���-[���=dϯt�d
�,q	*4��i��&��1hhRM�Y���,;d9�B:�!��W?�Q���Ѣ�#H��j��^/W%�Os�*щ���CT%J>�k��w�)�>,�n�J �`�Se���6�0�	�[�yO��'��Oj�<�AP׊'�\#ea㇭��0e��s�Fq�4�n7y���$.�n1&��?�:ʩē���z�n7�[���&�'C��`�Ԫ'�Ӽ�')��!$�/�|�'���j��+-�ja�4�-���<�����I��f|�xWRM~n�:�$݊�����_�#�b�a���E���|>=���Wz��6,�e�(U$u�k��،��\���Os����H�K�nny�|w�F>���S;.G�Q�ZՓ,��/���������Ce*�X�ڛWy&�KR�r���Κ�Cu�\*�$��C��6!�J�@Q�I҃e��j��«9��E�^����8��_�U{�4Ѯ���f`����G�UR���^�i�A5�ϭ�%�����iI��=�y���dH3�F�.i�2w�>�i[T��*<�T�̤ZǦg�%���.&P�J��j�G+�*���=;�-���v�c�&}q�[-���RE�i���{?
���2�&􌇂@Siy��#��t)#�O�r
єRab�Z�䠵��N��&�3��??ɘ����tql2KF֧��⛪��һ2�_��:Ei�ƷUS:�7q>�()�ԛ�_H�+�^�?<5�c����RWG���f��r����0v�j�Q]WŔ6Ҋ9ݍ1EL��K,���8UNI��Bb)e��f[G
9���B�\�Q~;	�M�/=��F�<8$Fl�|�*��R��C��.ڵ岰����-]���m���N7��E�.�n��f�P}�J�U<f�9�����RM78m.Ǔ�M��ƅ�=q�� ��J7j*uY��y��$1����֖(��6�Wqf*���L9��i1�\$�b@A��C0����4�ND�K,ؒ� 71��/��q�S�]<Dov,=K %�v���˨�I��-�g`�H�8�d户R��Hr����B�=4�r��!���%�R�·�����z��ri�"+��recc�f̝�M6�����8U��`f��p�Y��ù�2f_�����gS ];����4��0�1�|�S��b�J�������P�:��ǣ1��\�T��)��T���}�9M\$V`e�=*�tsf�eZ���P9}?�ty�n k �qES��JS�{Me8��1��ۭ�J���4���I���|�6�H*m�:�T�xW�2},�Ml�N�Z�5`�^�+�*޸�H�/d+i�ES)3ԝ?p��S����4t^"/�Hq���)� =W�'_�2&�<6Ik�������������z�����w�!��U�8Z����U�hl���$C��{�pjz=������
�
Ls�{2O��=3�f�
T9�Z�n�������2��G:�\�0_[S���:^�m�5y��:��@jI�j�<M� �[>���N�a��R����dو����6q�ly�Xp={�1�}X�����z}�Z���_#�v��t1�5��:ԑ�#G(�N���g?�H6��������O��}L�Ԩ�p^M�Z�ǉ�R�>a��Mij�� �噛)�PR�/���n�{�/wx��+��ƙS�'�ֳ�f���=?v�L�Ƹ������c%v���F�Mӧ�    �*>n��:��2S�ʝ��R�K&5���ZL>�Gmg��js�byx^�y��0m��TQ9/\��3����M|�bR�d���E��r�G��(>b}���L�"�W���T��|A���9��2WO��/}m�kfZs�ڴ^���n�z�R$��|��cD��B%E��MjӸ~T�g��j�%͹��u�G��[�J�av	��sX�-$�jJۣ#њ�=�����I��;�[f�����)�+ݵ�ĵ����Ӽy��QI��bF�2�9&?*+e�\�'0u�ms|�a�xT��jj.�J9�z�L��52{$"�:��S����'`�j�R��(=ܗ����,SXS��՞AH��H�jJ@"�O��	�8 
7U�~��S��}�@j�d����4���X~�O6agsT�<M��A�I��X�6��xǙ1���ប��d��~�?��"m��w׳���e���5r�Y�)��A,&'JQ��܇�=2�Wǂ�-dq�2t�i�͙'g֭n)����1::��$C	�)F��m�G\+�����(�c�w�r2Mq/�Y�a\Lʔ7iv��`�W��L�ԍ��,��K�?+�h;����=L�|_��Δ���ZT]E�C��������TU/-������/嚍�P��|5gQk�^�h��ɹڒ�q�&#�R4�`k7��� �肑�YK2�n���//?5Y8�n��nL9J�|��%���$��$b����v}J9���MB�X��v�`
Hi��%58� �{&�-S�͈qSg����L�֒�˗h�d�8��v'#�Ӗ>�����`Qp��T��JZ+8��8���O*]@���&G��T��{����i�E�sYg��O�m�bƋnH,��v�i��_"�2j�c�.e �f ��	ס�C4aXI�^���Υ��@����O8���9d���*ˀ���������(��3e��5���i�ȕ���7�f�˝K���Jqӈ��G���,�����/b1u��gdn}���k�����مr��G�8Ѫ������R��7�i��T}M�q�WY�R�P)�ܖsc>������dx��(�*(}C�c�O��ࢮ-��`3��OR��#�i�V_o���F�����G[4:P�)J����$�$���@�l�}˗r)�����в��(�'���$�Y��=L��~��1�Rk#ŕ-i�
�E�U��j��V��퍥9��2C}����8��L��5zt*��eU�L=O��쓇cV����O����ş]ƣ=k�־�e����l�6�U��ρd++�F�[$����z̞oԩ�������Yр2�v��o�|�.��ʽ��9�9W���ڟy�li��I� ����r�����}�}�m�rWhhb�l���s�-U�h������C���p�O�V�vR_�8H�J�@Vj0V�f�Zl@��"�|����(ڋ����TDqE��7��u��U��+o���Wef(e�=�B&��y��䊕_��G$?��մ��"�k̞L`����ݔ̿y���x�׎�J�QR���tv�ͽ,Y6k��\Nc#��S�}�����f��	z�v�p��NiQ�5RM}"!7�%|�����V�Qj7EI��U�L�h����f�ᢉ�������U��4�-AC�7�\��R��交�>��)!$�IJ��2/�ج0�V��O�U��?�
���n;���,rE�q�';��W[�N!I��.Ir@NMAL�3��(#̑�\Ļ˩}�=@f;�ܼI1�@J��$�;[�c�(�5)12���S-���3K���*�2�ޜ����w��Òy<��q?Mbq��J�2�Tc�u�~��9�_V��Q&ɩU贉
y���X��L���&&�م���9�I7��p��RN�rx�m�}07ɧv�ύ(�"��O\�#8|?% ]H>��K��fLD0s�:��W��43	�Jn�.��Ĉ q*�����k�w���$���
��O5��;t�r�P�T�l��]�@_�~n�r���^���k9W�!{�1X'�R~F����r�V��~�aը��(9�k9�h�τqdL����Ju��,�Ӆ�5��A+�J �ef��"x�If��0�X9�^ň�ؤ����ӌ�dX��̫�Эͥ*�H�z8��6��w�a;~R��.S_i8�"�I�f(���"�05%�#�&��cK`��F����s�lV<%%��t)�E��(K�ſ�p
�*}�+��<�k�R����Q4��N6�Y���g��(��V�/�;�����F��襨�O�� %������R����	[��w(��!V��O�:����Nlx/kQS�%M���YM�D�[G��N���ć��a�b������i��Y����g�m�%	Z(۸�C+	3MӃ]Q������t�Jy@P�f��X 
[n��P�0�L�y���>�D�~�gEP�×/f8է(E��xV1�c��R����j0)ܕ�%e����b���\(^@�H#T�n�M�Z�ߦ�R7f��O��a��i�d�k�%�D�պ:6ś*�F��r����� F޴��~�rs�)JJ��Q�Po����#�!θ5P�m,�.S���O(9鉠A��|�˺;�X����!�8�C�u�%n5�>ϣ���T�&�ކUJ��1��S������V��ɚ�3�*1

3Y�_>�]A�j�F�O�;��"��8}��UL�*>-Q�����&U|*U}�Y,>�~+��p3���E�]�V�[׳�7Z]w(9�K�w^a����?t+���<\����^�~�]|�E&4�hq%sQ*�g�kyUU~����阼���˴��EKy��l�Wb��[O�٭�rFm���se��j�������T�)�U��@u|��T�:�U����d���y�i/�����+�Ru�༘�.^Jc�4��'?��b;|�yR�z)����D��R�PK�j�//�O�p��qJ�+7d��a�+|�EG#Q�*��8)��dO1�A��^X�8�I�"3:H`����/6��E��\�Ԁ��m��+)�=rN��2FM���������M;e�E��9{�%i���l틗�a��p{g�=���h�����|�;,�|6�4S��LF�*IV˝$c�*�L(b�Lŏ;FD�ϊ��!�Z�P҈�@B�����QA�|5�g��b�Lթ�8�ݸ�J_�b����'�d������+9|����#�R����bT#W��?
s�0¢<���[yT���c�^9L#%������V�)^A��r1H;~�U�M�6�%
U��Ѩ�ԵZ�=M27TJ��M�� ���T{N�Z�N��gb �	A��m� �E�GOC;G8g���~6І���C(����+_R{��1��I֝����t*�]��˔|F-��Y��h�L$"/�����MA&S�j^�Ӟ����.FgS�C\��3=���M��it�%z{��hb��I���u!��Ԟ�HY�:m�k�W��˙�WE;0Y�ׅ����v���L.����"���>�*�L e�!���2[�y|�q�����0����e
��L���Ч�n!Ǆx�|v�\�`۴���b*H#@73�jXM:3���[�υZ:#�my�Z�)�}8+m���i�ذ>� ]a�.f}��I�O�a�c>L��>�Hhu�^c(��ML�MP窇���QR�(��Wu���Lr?vGFq�?��Ļ�h&��\ba�i�f�=���2q!\|֢A���&�5�v0�j���Q�p?�	��\��<
+�$Hޔ�&��TP��@O�%no��`ҍߤ�0�G����
�Yd�<*���oj�ث -=�:{3��XS%�˫�AbǊ����ԃgI�
G%���l�T�7Kw)�����y�3�q[�9KJE�	PPZ6�t�e�X�ܫ��� Mw���h��oi�8M��ʐ�������aSɹO.`1y=\7��e,���!��	6�q��a4�0� �1e-�<3���ZeB9�S� �^�\��J�u�j�Qs��)�ji�)��H�c6�$�@& ��ן����������扄28Q��œf    �ʼjzݠEծ��.V̞��U���ث���\y,�ݸ�ޗrb�he�P��P^�SkƑ��U��D-�$jط��x��y㴢��*S�E��y�q���#�L����u�����nB���"=0�k���@�:�z
Ҩ�|lM9V�]�+���D��<�d�!�sQ��'@吞�����&g}|t#w������ݜ<t?��q��æ�!@
OAPo^]g��E��Y��` �`�F�,�<
���"�z�y��#��/5���7��e�1i(��&��U[�V��g�3��~��(��7ӆY���Ѡ��3�UWOF��Vt��:����$Y_G�`�*�IN<]�F5z<m�eÿ
U����j�gQ_�ڣ�|��|x�[I�����x��\��g��>�T��R�/�� ����=�v���{��&�<���U:<:���q�s�?��lB']~[ qa�%�^Y8�Y�Fl�BO���&��Ek���F��M-\�4�;倱��oD��a
>�I��^�]���#e��+&��M5a������nPzѣ�>���s��b�M�^ɠ����կ�V�D�Y�7+U9�	�>:Vce� nIkFulUC˨U��c@�m3Uu��`�ĢZ~��*�R�Q�]���fm+���n*�$���q��M̄
�(K���7�@V=�J'zI�oҸׂt��c�z�8��]m~�[-�V3�:�%�Ȁrh1�:��O�c�$�)���7=�h����fH�"=]�ږ3wI��z�2Tq�k�ZA����^ϋ_��~-�a;'d:å��ꘓ�B6��\۹P���r5�k.=�� +n�/�F�����Zb*.��шZV"��Q��.G�R�c���[^X�)�h�n��,.�L��d��$$_1�ɧ;'�:��c)*Q���X֓�ZAt�C�c�C��k ��<q=�X��jB���.{=̩��Z����-�v�����VM?thr��z��"�7���f0�����.>�"����T�K��V�)���
�3�d��IOîW�������D�Q���^�;��h��M#hЪ(<7h��@g���7�ɩ�����f#�^^�&:F��_�07�Y�?�YV�l�V�8�U��ea$���4��:w�l��A[�45�11t��ݶ`�:�P��E���Sk1��Mw:�mf'��e�e�g rSD��/��O<���v{�:�FM����kUf�E����Q������*�9�Ā����|��Vt�:F����3�j��܋�_�V+����j���C`�|?�n����>�[�[y�]|F���,�����lѣ<T�G��r�v?�fq�^��Id�Zmf��+˲$�$�I���f�(��Jhj���Ƀ�*D��.#���F�K�m0<E'��r�^��٭^ۦ�4��w ����m��6E�&��v��WUyBY�I%��I�1������}�MM/����Ep��u�4����ƚ��9��
2��^�Q	_��t+���˜E����_��Ga��6�Ta䗝��ͷQ��Ą��o���.&��XM]w,{}����3�{�}�we)��h�����(��I�6�xң���*�'/?��K�C��/���� �������p��C�/�����P�!ي��,Y�U,\Y��\�Qh^��I}sq?+��mze^�k���� MQ��7�PF��TR�b�
k�U���`&����
޵(�%YR`���C�d��àr�:\�~0I�I.I"�����q9���H>i�M���x`����V[4�HrA�1KȢ!����r�� �y��$����G"�Ԉ�*��H:�ȥQ��H��o� ��I4�<ꅦ��J�i\jj��RS�p�0�ZO��]$*�it���0g��t������0U�Gӊ��1�z����<]�EP�N��HVl�w9O������+��jU�2c������`g>5� Z��|�L�,�(�������$u����XY����?t�5NYU��)S��K�>��u�~@�V�{����i�C/����e�'L�]w�$+�о?��W�ñ����g�Ym���I��ȧ����g��O�i�x�Y�Z�<�E�����������}�G�C._�s
k{�M���	dQH��	㒨PYs��E�oDz-*���R�bQ����r�:gr=7e��z���LA��a'/75Dv�Jک��\`;�v�P�jJ\ĨG�q�ڦY��ACE)U�IWO�ݸ�U]N#'ë_���Yk1�� _Ӷ}�t�[i�3����G�7S����0�p�'_���b
Y�zGr3��Ow�LI���VM���x��u�+�zνY�:O�e4��X_��\��Q��Y+E"Tn+3�nS��ӘAz��pWS�l6��v��|&���OA҉N�Ь5�)I=�P���G�^"$�RNA҉n'U�+ij���O���4�<gaU��hcj�H ��}����O\O��I @ϭ�j�~WE��c�Y&J�K�g?�N&n�ބH%��fXGa4���K���m���Cw��Y�2N�
_jqԩ�FX�$���ꠅ����"1�\�A/v-�c=��Qέ��������K�����t�v��[9
�,���J%t�Ǹ8����M�Y'��2��As"�o�Oc���ec�
�3+ã����OΖ?�O]�mGZ���;�9Ͱ�E2����1����M�����p0�P���MU�t�h�H�4�������ħ�����s��yJ�fc���(-�%[�7�%�Un�$;3^14�&�R�2&���j ��7�z�_����7������3���io���y�&�d�K��ښ�L��5�R+M�eIl]���O����j�F۰�q��[���D�XI�>���נt3�Ji6x~�]�U���$=v%�9����IcP��3�RM-�Iy���礕���s���d��2%Oz�r:�E.�9�[�t�Y�V���
S��L���N�,t�X>-bb�j�&�Q��ʟ��Q'��*��Z�8;��ue��&wtN�xQZGՆ��wr�LzT�V�4u�M&*R&=�=�LZ�O��i���b��u�LZ�V�0r��H����<ސ�S��!���L`Lg�V����.Ȭ��M��43�J�*icˌu�Jz��n�r�mc�'}�ً�/�V)M'�Q�Q�6z�_���+������H.4���]�A�\���ld.����֓�W˹�s�&�S-�'����+q}s�I�	���A�6�r�t���Y�Pg�����x�M-���)���bɡV���S�/�	���a1�7�H�-�k��8_�4P�F�F�eX�c�N�_�C����o�ǃeܳ�x+
�s���t]��j��%��Va���?�����ё+F�'\���A�5f�����>�������Y��eMM�,Z�C�%Whl2UWhy�g�~r\���S�E{�CUq���� S��+<4?������Bf��Hm�I5�<J�=�<��B(2l��h�}��7�(��4z��<�^dH���*��g �l�YI�9&�╳������4~�����57���W�V�?l��?�Q<7��h���Ҙ�Qt�S�� ~�}�&EESԱ�P���Wi�l���H�3w��VUk,*�aٹ�s�J���57i���.�`V���j�"(@|�D�u��Zƻ��RZ����s��a�i�U&����t'�jT�����
W�b�|�ˣ��Ӳ��g}�=~�ߵ��H�$�k��v�9n��w#p+o�/c�X�/7���<��E	���0�$J���AI����/\��r�fO�@�xW�Y�<|�b.�i1�+��Y}{k�V3b��|%��^��a7��;W~�����q�5/ނ�5�n�������O_��@�o~��W�fW��8�K �O��쒅[i�r����U���wIYz܃����j� %��ҹ����'n�0���
��b�z���P��MV��aP��[�{�p���O?��B˛o�彙��˔ʞ�&U��#TD��8a�Z��[���2���@��?�/n��n�Z3A��7�����6?U%�qӇ��2i]/�    �IuY�y�^�櫛��|Y��卩c�!CI�?��Ն����\I��Y�x��Օ��!5�J��SG#��{{l���T����i��7>]Jy��T#]���?�<�9&���Q�٤Y\O�n�%L��V��N�����&I��$��ToJM���-V*�?�E�3ݼ��U ڙ}�!��^��ʩ��'�=[�'=5�:��\a��X�>Q�����
�)�My,2�>CJ[��֌���?g0c���mbT}��2�8�dh��z�&M��8���4�뭳��a���>͠�$����:_+��l��4��S3���/ng0)�=Ԗe�GN�8�0��\�!�4��q%�CĹ��QM��'���z��4��^�:5����l���]a��A4�� 1�f�x3[L:�(�M�Q�Y�p}�˔��y�p�yN���*(a2�]��)�UPFvYi0e�Ԓ���q|a6�P�$E�(��I��F@i��2�b��~��������x�b��D��ē�K��S���iœ��q6�J��@tï]:Mm�M�@�xX�N�K�]�V�S*Mb��1�zz8a�Lo��!Gjm��H?�go���G���V�R�J%������$���n���l�D�_� V��� �Gn�猃H�����N�Q~o�[�)ȃ�o�9�����B�G(�\O�2�{����3�=l/�����YN���~o�RQ������M�,��2�yr�JV�9󩠐F��Ş+eVqʖ%|�׮�-�6��CV34��0�"K� �־~d����5,Il��hY紎�0��1��������ՄP��^,1�|ҝ>�մ�l�g��L8������y�	����Xg)�4w�{N�����a�	�S�:��ч���M��Ykn"�_����Y��G�I䂲l�V��
��X��K�96���T��j�br�p�ц�^vl5���t��uG~c=0�]T+t��gq��/`Xueá�6jnÁ�����k�P�K�CH��ν���іC�p��#�3������"MtȬ�Ȭ��p<iߏ�Z�d|WM>��%�l{���k�!�/OÜ$s��(���*�1�a�d^�>Ψ"F��Lڸ��Q�HVv�f(�[�V�T(�nR#��\��m(��[���)��;�i6s��}��IJ/C,�f���8�k�6�,��_c�"D�R�F�勻�� ��zA�ԑ��dk��PS�<QrU�{/gaO�z���X�2�Y )J��)�?N	��2~Z�H8���QU���f���Gz���R�L5�;�r�Z�`FQ�0�!�:�ᨱ<��N����2\uk70���rɩ����Wn�r-��6�������{�7��0��Ī�d�$! ��M���W�D��mN��������}��*c��m��4�`�L����Zn�"f?7U�W	����:��M^�<��lV�k:ö.��6�}y4�4t4��Ի�uN=�LJg�I`z��B�i�c�����(��ӥ�Q=�˼E���]\�O#2�L�)s���P�kHa���et̓��U�:���wԘ��hc��R�E,��o����*�4n��@q[�h�w��t�#9%�%�Ugm��"[3�}��/����R}]j�D#��M�R��C2Z��gm�q���4�̫W��kס�Q7KA��N�x�:�cm���s��%;f��H�hb�\̪�uQ��]0ʇm|��G��G�S@Y	��"��Ϝ�	��$V%I,��1ˏO��r�iU��I;��d��zl��4}��ޛ�Z�n���A�\.�=AU
k����֒7��!���0:�'�HPH&U���3WGC���>�%�y��8Z��2�-�>v��Dq_��V_D�D�*����:7�&�ݿ��؇5V5��4�Z��~��UD���W�nr�����ؓn�Q�˛�S���{ҧ]S廪"�,�'�)G�1׸�w�(�}�1X=Ps��S��Ŕ;6M�%�M]��4";m?�}�C݃V��F�8�x�	Ԋxe�-��a-���&L��m�U3�.=Oyw3%'�Q���"��}����1_�Q�Ɖ�-���`����ag )���gκ�
�M>�������QEka��QS�1��N|
����OuQ��2��:ީ�8c���^��]M5��+��^���+�&{�Dy��rè�rE�k%��
���ɺ�a
��J<�xM�M@Y$�E:7�$��΋4�qʶV�Vҫ'��dq�f�{}pїlE��3ԙ1=�u\�6r[֪;�~�ʻq�q�_��Ƈv<{/��� A�Q1i{!�wuȺx7mʿ˧���p��/B�V�H�!V��y8��:�eQL��󏰙<��H�U5N�F[��\���Z�zO��Nj�,�/⡗s6�D����$��$��s�k��|Q�I���{�X�)��=�!�
����g!'�z�>K1�f9��UM��,Z}D��x�5x9�v�L���$�(mF�!�N����Nu}и��tȐ���ɬ�^����~�c j5z�����	y��]��7bY�%*uY]%�Nf��t�l�QҫI��)�C�D)#CN�9��I��4S&yaY���?x��}��9�!��s�L�3�B���A�>��೥4|XJN�Ǩl1	���(шC�Ub���{>E)2i
�3��������p6).l��|�uz:� 3t?�`64g�+�&��Q>�{��t�9�9lcc�y��Q�JOA��@V$�R�r5�gP54�$�Io������XM�3��#|���ք��`}�rP�YSx�,���C���B��;��CncCvNSEG�et��,���#1�K�RzL0����SV3���:2i%c��TE͹��<�T�����pS�jG���Nd^���9���v�?�!��p5��a��ѕ�ǈu���ݴ���l���,B&1�S=��Z�عҡR�7��\g��̚P�FM�r��.��o��L-�x���k-��6zd9��:�� ^�?��z��w��#C�|ա� ��X:8x�c�J�9���8D�@sV��뽓[�A�/�s�3�1�A�c��rc!��O���A�*?W����A<EH��?ר����[�)JW�1\3%9t�:�n-B߯�d��RV�d/iy�DM�I��G��S��Gy��M�Bs��ZhM�eQ,�9)@��4g�J���l2vCs������>�(͟�xUޫ<T�%�&�b�hR@=�u���Zܩ�]Yr$�6���5+n����ԽY��'eo�Ւ^��`��4Ri�1�x�zB'��H�N�̈́�l�PN����b�	�$���u)qT�F;2s��U�~���s'�+�	;�~V͉$��BFѯ�� zn��$���w)F~/,��R����3�*����r��+#2�M�M�����n��Q�HgP�=:P��.PV��i"`�J��t�����A�<���w�Y��;00�x�#��#	��%�	���ϲ_h�QZ�>Xj_>}�I@�/����������W+�v^"`f�{��9[�2���v�&��N!m��},?����v^"� "]�1@��%�혦���n3��]&VA]Ҙ�߸���U�@���?������Vf�1@��X�8�s�8��Hn��Ta�J8�B�x+���+�6�����U�8���#k2c,�.�����=���ܾ~��� �A����r� kW�5E���Zm�ic�ӝ� -�&G�׆��A���@F���4�+H7nt_��mJ;w�����C4�
Ar�k��}ZL5�6(x�&�����6%{�OKA�=�i��?-t4=Pи�i��خ(�@�˷��TZqc�\L���boC׳X�G��d�lu'	[����<s�f(ih&T��Z��f$��oY�*n�hr�?���ً�[����'�y��pw�揋	�嘈?�O7v�t!�vX=Lؒ�s.-7m!s./����GExQ�f�Nz*E�̩^i&Q����(e5]�7�]#�KE�W�*��Q�/�q1CI� -�Sy]ئ��9��8+��E�%��_�]yL�W���=�V�y��)�SՈ�p���I�)    H:����^��)�ʳ��d@V�On�i+E��`�/�4�J�x�8��߃w`C��#�G��5���3u8���!��Æw�JZQ���8}d�.7'6��@F1|C�!~�P��˓��� �b�y`@ؒ�ۣ��C��d�h3C[0�Kyu��RV�-eM�j��w������M��b���[����03��Y����sa�R�^�s�r�z��������^�CⲞ�PC�Z����32eEJ=[Gj�o��z"�.���_�X���R���d�_HO�l]M||,�<�2�p��E�95S�T�����C�ZN�s���*��qR��_�Y~�R�?ས�Mx��x��s__~����a^]������{3Z�< ��@^�tM�=�i7�������r��?�dxց����ׯ���[�h��������:#��8!4����U�},b��f9��q���w�~���]��@#�����J\F�e�{A�g�;A�f 1����.N?q~9�
~�D|v�F��^_js�ڪ�*�1t�l
3���NO�X�}�17�G����j��kH>>��_C�-�U�M�|jF���,�d�(ef�p�%1���bS1�/e��I�^�g��~�0�������H�2Q0�9^Z)(R���}��YyV�'�n�.-$y虳�����D��f�z�u!s-g�Lsj�X3ܔ���FS��_�K��+O�ˍ�zS��hJ���>D:3���|���g��N�(���R��>_��ش��f�T.�쏴��cG�Y5�R� ���>�ߋw����>S��LIy$�,��+� ��f����r��)��Nl���©^3sV������1��Q䄅q.�v�T�Q|�n�ǰ$]׿�Sѽ�%�
u�RS��ǈK�}�d8o���<*\CY�/��nl�;��-]YQ��[q����Mjm����T��ZJ��25�˯!���u�J���
��
˭��l�f�,6�ճ;��bl)��q��B�c�*���ӠD�]/����,[,(��"��0�O^Q�ď���A�|2|�Cj��|O�"����H�mXz4<�����3�PLW2^�M�/�B2�^rjufF*a ���rҖ��_E�*si�5�F���4�e�2	�j����w��U����o�a}9.+*�:{+$���ڕ���Qt	��F(�Ph��(QHz�WE�%=z��j]7R˪��]��,���fn�Y9zG+�D:,�<=!�|G��ʧU��������H�3�@��������T���7ݑg�APK�3���JT�kC��"W�4G���=B#�b�q�(5h*Qʽ�jDh]�r��愰2��;A�g��@hǍ�I�`f����4�h���5�qABa� �3��]�׺^('�����yfٴIWj�Mip�����$D�Y6ͳ
�,Դ�Q$��3z��-��]/�k+l=�
w�n�����1�q��V�����c�I	U��h��_?��cN��	�V�	�y����_-�| �@�´ ��� �Jn���x-������8:���nF�)v>f�
x0=Q� e�1��I�b���"1�oP}�����pLu��ʉ�x�Q�1��|��(�cS|�Q�m%�G΀~n+�F����v�1Z8F��%�������O���L'����X�c�0>� ����
 ���B�������~⮂pL������h@�c�����+3�`�x�7�y�'Ϗ_�
��7)s0��F��5B�FxБ#�߷�~
-���-��ͫb-����2N�3�l����=^&���I<�^�Us��.w�|��/�c�`oƆ`�~��B�+��6o��r%|+u�EɊ�=�̾�l�\�o�]iu�РK�]��W�r�W���\&L��4�!|t�q	��w���>iz(�xX+����J���7&GM��>��g���+|�ܳ�$�|���ß�v#��}��@D�
�q�߬ �k
�̸I��+@��]WҌK�t��x���_���1�x g\�����f�cߕ��A�a�d�~�!�`��py��W�u�?����D����K�
]n�\�?��%�1͙���:ʼ����1V������,I��� ��*;ח9�m'{�Or􁸿P�K��Ǘ�#����_�>�$���<Zy���Z8�5�F�?�Y�s�\Q�a>�^�U>F�ֻ�%p=ڕ7*-��lVi��J�} T���Qi��	E�5�i��	��!q���!����ְ�i��Q�ݘZ�B�w�p
P�O�(��n�
-#Kv�l�W��чu§f�@�N�UEdQ�%
8�.d��7�t��R�'�FI�$܎J2?z5 �d��2j�d.*���+)�/&˽�%-`��`nN����q�{���:��D�.(��]:�s�WS���V��Qy_3�pb�&ٙ[�
��+(��
��oR]j.�� �r������\A�
��\�лc�I��C�47���`�'������� ^���[b�wp�ݑ��7�q-�A�ɐ�@|�ƿ��;�v�QÿGe��
��0��PFxaނ�mn�qC+y��Β_I���n�s���8܍��^����%>�*�O ��*�C��n�u��(Ƀ�6C���'I�W~~�?��c�h�3>8�4��-�;�<����{!�F~��о��C��<*�@qέ���ޓ�wɮG�M��1��s5�½$���W�@���(t�{Ez���Q����]ww��EW|p�Ԯ�(3�x�SZ��ƃ#�jTN�j<�)#O�t�ƃl=��� �I:�����N�=\ߕ4#�N��J�������-�G5Y��t�ȃ��������zm�P��a/�����ը�����s��u���A3)��������w��U�����7�x��{V�k���k9�����Zr	"�6 ݵDwm�1uD������u`7'^������;����5��N�F�����=	لl�%��Į����\������]g��w��z"����]�qh3 D��]��J���~._�����J�e~������R����c�����r�K^�o+Ef���3^ �Kşu3���hA�/G�[#�|�
=JD&Z���SL^YC��e�踆U"�)��!��DtT�V�(z'g�v�����@�&��]��1h0�
��w���s��	B�fAL�B=����
�_����[>7��^���c=`TR����
�y��Ӈ���w�j����.I��R�����(DZss��Y��p<)u{yAw(­XݑlB^*��	�_���ڤ���][W�{Z<�O�/b|��b� A����l�x�9�&�y[-z���O�-|�</�Ń��xSC&��Y��4�
����yGZ<����[{�`ٔ}k��)�۝"v����矺����;�w+uC�Bm�,�j���e���b��%ǳw }��W��*6�/F��F�Ϗ����	�C�4Ϗoi����k�S�ϡە�_���cv��D�^���';?E�n��n��Rlz�jU
�R�g��m�rON��Q���9�T'�;e 6����.�j2�,N�x��]��|$%�b2�9��C���J;n� zX��Q�ۉ���G�/�IJ�g������g�F�����-�uW(��6����8ɠ� U�=��MݟM���÷��n��~f6���j�&B(�"n�]ˌ�5�ƅ�D��")v	ϲ�� �w���
���'�� �A���M�>C���+vRA�huǛ�E�$z����ۇo��]j��k&�s��|h��� .�W�J�M� .¯�)�W~�����T��_}a��WP�S��Ǌ=j}m����Ρ��$-*Dᓲ�]Pչ6�"��ee� Hh�E�B/�Ũ舣���y��+��9���e;j@Xe;�� ��?��\��X�A<�ĺ��o�	�&�)g��wgiQ��;I���6��5�n�M�d;��5��7��<ЋI/�)G�I�o���$��'\⚪��:��"�$u�K���d?@:D�#���<�V    �{l���=�	|�*��m[���w��m:�W�O�c��Ns�N���l�M�	ܲ<�vo��p<�7é�Ǎ{k�������6b�����ӗ7uG:�v��������8B]b���<�Э Н��(b�'��T����N�SN�#�����H���{.�IR_@�F��l*4Ƨ�?���c@�����֟�s_��.��ѻ�y�L�T�E�N����܏�>�	}��ꔺ�k�Ѝ��Ob�^�_A!.�DpC�]��d*�x�It�J�c}����M�R'�_��k?�w%�R����۹��V�:��x�j�
�q��O��]����ෝr���:�m,�(����%�.��b�,�)���~z8<,�H)[�AoLv�G����J�q#� ���\j����ד���d�/�8�&�g9ao�s�UB4��Tx���Vd���5@x*��b�n��+b��sV�=8��;�?C޿۝�Dp�&Tq���5p=��O���5�w@j8��)k�
��UY�֝%�@ 8c�g]�S �7f�DH��l⚩	wpڄ���J~v�m���-,��
��m��p�d��}����.�ᘹ�.�� �;���Ԅ��ܾ�ԄcoZ��+íd��Iᗊz�k�_+�N�@�|�r��_.ʽ�e����ul���E�w�-S���n.��T<Q5�T��=15�7�HuU�l�Ԅ��0c*{�.����������{��1uz������V[u4��ǆ�t�	��I����8Oz�dc����W�:}���Q�=�.hA���U�����;��V���I�e�������;��u#U��k�
��| s���v%O��/�a��m wwؘ����]�����P�a�_Cn�]��I� O�LO'���B���������:o��P
����4X�G�L��P�_¾����h��	�ކg��<�5�;�|~��o�m~�=�&��&��,=��{|�!͟��?~�F�ǧ�\:�qY����9�>޸�&����౻�Wt��̤3��#���g�荼yy	P�[��_3^��݃�=B)~'�n��!��g�yd������W���~a����Q��}&��$��ˇ]�����g����=@�����K��|}��_�O���Y�?u{�ݣ���\��Ƿ���߸��e7����q�ǜ5g�f�S���������D���7}�1���� T�������E����b��uP�W�e�; ��D�ԍ���w�M�]�����42'�~$�� ��?��UK}�KހO��Y�.&��RϜ��=�_=�e�%��SA��K���d��+�2l�w���ϻ�����-�4ԇ?�l�]����݊��n�

�I�@���w�����
���H���㛎��y�&��c0��Ds�u"(�:�;��#�|P��u����7�	�l�Mܑ_�:-��(��[luZx���Q���W6a�-��5�g�� �����v��q,��'�ͣP������^���
�.��E��c��y_���_�D�߷�~
ͅ�����+_9k�H�	V�w����BP�h��B]l�'�[/�»4�z�S��O��M�'ЂT����_&&�B�x����у�Gw�ܵ<���-��0l�s"A+Ђ�����-�>9�{��G��xR��x"��xoܓg�WP��;�<]����p��KB���O$���<׬$�׬괂���x3 �d��X��;z�����i�~��ϒ���$�����Y�i�Q�Y��_C~����޾�G ��xx�Bw���$mBw���	���sv)�`~�q}-��{���\���g ?+��\�K�"��\]E��^g2���I�i��0�x$���@(F�Q��$����H�o$�C�cN2���x͸�]>h�����t0�F�0�Ⱦ�(�P`!��$�'	B�O	LU8Jzx��}��3| ���.^T �|�(P�>�>�1��1x⑸�p���v���	����Y;��X�˟�����x��&��
�_7�/�A<�U^K��b� �A� ;S�[�'����{�v�4��X�E���X�|��o�V �����C�0���2o��Y��NJڠ��.w�AÁ�ӄ��R���r��RdeU���½��O|��xן�� ���C���^�H�4�h^x�H�������p���c]ƻJ	������R�94,�SF�P^g�����9�m�g���D���zWr$�� \�s9���R�
�S{��GW��i;�eWg=��d����Q1����u�`e�'����x#F�#��2��4�K7~��]��j=�5�wɐ�.gvɮ�b�KؾCݥ��uʊ��{������VI	��͕���6����'���\�����n/��30�������o�A�tow�Y����5�~�m��?>W�^��%|	��
*�����³��OQ,p�J�ݜl��=Q�f��+�n��;��\�]��p��m��Z�W���/��4x ��M��� ��Z[ZY�W���������h�x��s__~�-���_2K9������B�9i-�P�K��oP�3g����wq��/y��q��Z��c��u���2K� �bd�,�����
��)xݵ�7�rx�Jk�1a��1������:3�,��Vw�|�>!Q�-�.�Knk�'�R��&���*�k�p��#յ7��'M'n$�k޴������7���0�7��{��O��q{b�����G^G#�M��_#�߷ۿ�KG����^M���w���ؕ��m:��������5 ���F���;no!�>��3�畢��]�������'nY��6ї]8hFw��D�P�N��D�+s{��U�ⴓ{�&�V���9�'n¯;q"`�/�6ѯ(�r�Q3�\��q�c���I�F�=���Ѥy`�B)G�&g�OÏB��WoѸ\�Ac�_X�|��q��Rx��.I�����ǲA��x����_僺��o�����}�l�]�H�o���o�gj)�6٤��L��5s�R�z��3@��.�ˇ������ݤ|��C��1�k���'n)�j��"��s�6s~�虥�o�$��/ޅ��b�.����$pH��#q?u�@x� �T
�Ͳ�0f����lH��Y?��2Z׃��.��F7�j2����:�0��K^�r447!H�>"��/\��A�#B���6���c��|�X}�ы�m�t�j"�U��_h��1�W�����A���)@%�L����8֣������L�[��c�CTt�%.��{Nw�Z�,�6^Fo��=M���DZzO(�E;��m�s�=�	����S~���(:���s�JN�� ����	��o����(]��?SP��B�)sV�R	<F��tΙ��)Y�C��R��V� Ȼ��$C��}��p����~!#�����C8�����������r����\��Ƿ4�s�y.�oG(]��G�8F?�[�"�%c�:9����*{?Q3{��*��)��"��=[ϟ{B���.���5�:�mJ�.>9��f�Wɮ�x�2�4d'�� C�#�섰�!���R_�G��<'=�Op<�h8B�FSܞ�?%�f����a������㷱)���l8�x��dݔN�ܕ�&�V��kV�.͙ᒶ?�'�����gl֖{x��f�w��:])l�]�
É�����}�l�w:���o��~?�Z��5}�f���6��6q�w~�lr4q=����2�����"���M��?3���=�������������=�2c'?���?�p~ҮO���`-��:s��`������s�~փ{!���=�?��"4{4���D�o�0��Y�`�eA&]g��������f��W�?ȶ������g� �ith�i�
\9��tg1��Ob4���G)�g��T[��D �O�����3�    ��_v攮c���n���L�&b�$n^��!,bhSd��B�4L]`8�&��������"����Pq����s�㗗O����_&�.d�4�緻]A��k�=l:`�bC?�l�/�U�����gyB�@A�w�tgyB+�@�A6.� y|F̛Q�$�Qܑ
8F%ߢ���;9-�P��SZ���&T�ī�<��[^=?���[Eeգ>?֑�]N8\5�����.D�7'�5�.�8X�����w�n|<�}�9�a~��,g��m-�����;�����W��Mt����3�]n;�tz�'/������v���X��+��� ��Q}"�_�v�FdG$����z\�����w1��;�������
 \��gm:~�}��ᑢ�mvl7{)���8��}�m\^�H�2du�҄k�7w��׎m���z�눸݈�]omBw厁0��
�؞63z!�LZ��y�s��	�{k���&*B����$��#�4���]�uf��F�RG�TuHE����ȝ���w��'��C�# GV�)�4+�`�LI? #��U3�~
������$Ҋ��}�m��p����gztz�ì��%[�{�&L�C'.�A�[tR�):��\��N?;�9�[pI�{�/Ӏ{MS��NY��a.�\(�3���TM	��a��\�0�C���L�a<���������0��-61s��L
C���\]:_:5V&F�؂���*�ߵ9�ty�J�<�C�NkW�a޳��d�t���nK�W3�銦��)88.O�f>�%�K�G���0D��;��>��p�6g��>�$FQߕõV��e�0Yy�ϼ`��#�Eņ��_
�߿=Ś�99�1��~Ԍ����X佪0��m���A�
u�8���p"��h��u8z
N�����|ުJ��j�6/�t�{?h�3t�]�g���t��q	�ޓQ����f�����n��ױ�kF��n^2�%�(�jnS�nm�~��el��~�%!ǡu�V�wD=K���W��O]���?+�VmKW߮�Է֦����k���}����[j�9+m+�W�\�L��V����u�{5����T�뫞b�?�����U�V8������O_�>�+wȎ�w�N�on{��Zzj��!?�6=5��Sb��j�_�SM��7�5]�'Wtǟ�����$l�y�����M�)8�(g����|ٸ;�����<a't��H�:2�E��ň�y�Cv���M}����@t/�>?��W^G��rϯ���]��䮠�;t`��u?a��|���Hda���!N�Z��֍�
��G'/8���������gM����&Gjo�������C��w1g3+�����@�6��>l�k��i����6��^f%N�k}ׄ/�a�p&�����^g�Sx�c���$�S�Ó���&������U�o~q��WW�Rh�'�z3́ufN�~̜5����ѽ�����-����M��̶L����/_b-\7��{)��i���v92�a�I��0��jR])���ڈ������.�yݟ��O��_�����\���������0Ǝ>4���O7���Ru��F�4�п�>>F��&�!��z?z����p ���~���E�Z��/���iGt����/i�`��$�m�`pp���1��gt����^&O��fH�TsQ	�����~�n�rU�?M�+��7�+��x?�?�fF���^y=��N�Bjr���uCc�\�K���k}d���W'��_�W�C��x�x�)n3���#v�N\�:��/���\�O�]�
�f������Ȕʎ���zp8�t;��7��;b;ݮ�}I���#D�ݿ�p����]8�wus�$�%g����#�ܳ�ʴ�B����y����7+?L&������o�������q>���קg��k��'B3�����	'�n������ؤ:�
W���D��jU{_��X�����q=�9�������&*��T:�9�R�����u���Y{���S1\FM�b�'YI�����\�Y��)����0������rs�WsL�i�^��Ї�&On~:x�8�
���m���G+y~l��F.����#�r��;�bC�]�y~�;b|)i�`��tC4c0�~�.|���ٜ�7B��|w0ٮ�`��d��̙Ї�/�j�Sx��Ĩ:�t�\����:~2hn�`���G�u��x{m�R c�'$�x���4a
S�Z�cҤ�[.��ۅ;	K�	�N�^�	���':Xe\��]�-Nø��r9�����p_���v2}m�%�;�o�y	����I\��TV��ק�5B�MBv�N����C���o�m�ڙ�r�N��f&w��L~����f�;�\�~Cxˁ��Z{����Z�Ls���9b��s��U�%�ud���9���L���<��#�/�ϼ�:2���NL��Y<>[7
?���rid"ʖ�7a/�49�C�)wم��VC�^�]�L�9�	�.��8
S5c}I�j�5��pp|���sN�|�s�����Lt���|&�G�8'����%��W9M~�+z�f��'��n�.�s��S�S�k86~��M�SLN���/��,'o'�i�!�K�pI�͆�&f���7ށ��kW�0<�ʎ͵/{���&vl�+8�A�RN���_����m��5�;�Lk�G����%����N��uu2�_;v��}V��	�7�fn*W�m���}��bΦ�Ot�iPW���Vo����"�ڽ��\�i_����x���'�U,3��N�`��+���p��WM�Ek_8~rWmZk�
���W����S�V�W�u'G�ۀ���~�1C�\N�5��{����X����#^�<I5���\f����տ2��+7V��S�@�;`��n����gm�0�z8�)�!g�m�?oL<0���?,��7."�$�K{Sև��+׳E�ǜ�!�����5�`���ޠ�b����A�����*F����e�D3b-n�D���_���U$j���=R�H�����&0��o��H�®\ȭ?H�mMbbco>k0�o^�?ȅ$k,*�BC�t�z}�V/��7�엯��L|e(`����z��w��gz]����Ht�����ߍ�uqk�y1�G2cN�"���~�����n��izf�͔���t�ߋ����j@�-M�Y�o,�5��?/�-b��QSV,W�0�w�o���s�� K���/��
���k�
��G=n��J��?���kz�=����D]���ܬ�?p9�]������XC���7�و3gn��#�F�ǵJy�.>��F��(�Z�X��ZT�V��<�(#Dv3���E,d� �p�|��sU����,���B|ia��z�����8��Ix�c(��#'�ݲ��
���A-m=l��Iu��k눦
K�h���J;lj�)hw9�/���sYN�0��Y�k��"�eW��K�TYI�h"H.�yW[b��t��8���p�0O�9��4�Y�D{6�%u���׼-_..� ,�-�ʄ��B�Mt��?<7I�@{
~[�Dx�S��4��Z^�F�9���Y�ݔf���T�:{��������m=���T�r���m���5�������x;���Z���^��RV���͉̽�h˯� �$�ʒ���Y=�֦��E��	ŉ��۰Wd3�\ޫ�e]K
%�����i��=��6ұ�2�<E��L������SQOeoҦ��Y�c�9q�2�p J#g )'�뛢]-㲦�q}=�y3I�Z���긽�����W� z�-�^�&�JV��T��uY3��#\ޤ9�B-���/r�܅Ǫ�ղ
��*7l�:G�cY{�y�P������|��
��)	M��q���V�^��uӣ����xe���ڇi>�L۲�tqSI%yXO�������\ s�k���z��a
S���ɥv��le{��l�'���e:G��9|�z�gx��B�I2����Bi    ��1�]�k�F��w�p��������!r�
5m�$�����8�v񙷾��?�K�'3@�̽˲e��,�+e�k֓��o`H"��"7KLP�t'��g���X{Ǚ��#�1��x�{܇��j�ŧ;̹�rm���l��W&�;���@���*x��폎��������%�+��56pg9����j^�^��m�zܵ�x�^\����@/i��C��4f%U'+����]'�s��\F�Exۢ�^"Ӡ ��y{=�Ħ���=[\L�o+�՞E�7�?�LӠ�dWO/˷b�n����f\W�*ehh�YT�����e{c����z�j�f3Uqz��2�Ԧ��մ���?���L��-�v�k���h��}C�r=	��.O��T�&�Zn�����u;�7q;̤5R�^�)�zʝH����㺙��bg��64������A�'S�c2��H#�ӫR�-���-j+}���YA61tz��VF��L�������[�-�ܴ��tb��lꈻ��EBx�u�l*}���m���w���Y���$�k��]=t��g���H�ڽ��#��U%5>/��,�Qž�~�*:){�����N��Wa�|j-q}�'�w���U������9}+��[樰�J%���P��ImG�f�Ky�6������C��X�8J��_�Pg �ԯD�����"�e�J/�q�~�����y�����e����Max���k���	�5+<�W�b��i�*{՚־-q:�7e��b$O.E�.f`�������ʨ�UN��s�>Iw{a;���V�RMC��rd#���T7C O�q=�Y�ڙ}��i;N���4���픚W�7
��(��d�m_��ō��$�T~�**�*����}��q���@��Y�Ĵ�a�ú�����[߮ɠ!��=1T-�ZY�;A�� [��?�.�b���a���H�Ļv!�|��c��������m�k�x
��'���X㈪>ՇRv5�w�֑>Ah4�������~�>A�t�;	8�k�V���\���u���罸���݌�1���׽ �?�ѯ�������2Za���0m��t�^ Qo���E_j��[.��=��>�Z�zR�l �;� y˭Bw5X����4��c^�kp,ŷ�=�����}�`k���v�
�I%��*!����\��2�f��hd'�n/7V.e�D+�0:���B����t�Rk�2ʥ��.H�%��r�g�-M���/����#�G,K�Ak��8�f�3��/tL���C��_��}��-��t�"_����WK�	�]��Zu���}k��z��&O7���1�&���a�^h�?Ք[W���.�T��˩7l����c�X�̓�-����#���{�ƭ�̉�uq{{�e�`M���ێ���>����j�{�pF;V�tj?�2�݃�Z����|��j�#H���:�k�f/��,0�`G�^0IL�)ݽy�۽�kw���\e��8�/�Ŕ8s����L��}�V2�wM�r��oƣM4W�{M��圔6��S�[��?��fw�W��f?g��G�f1u��d��=��g0������ݍh�,H�[�۞A���6S�J��8���=�ch���ĻmP�ګ�X3���Z��)�W巣BF)�Wt�#��v��ïO���V��t�]KH��@�M�Jý�uHIZR�2.��RW�oLZ�^���'*5ٹc%�F���8�B�=P�p[ܓ�k1���Jg:פ�����TB�����{G��0ݘ���P��:���}�j��[���:!��e�����[�F#���cm$\M���*�ݝZ��P�#HOݼ�f�]��"�V�%��ծ�SNM���o`W���5�L:�ծw"[qq�1��޷-�u�<_UEn������^�P�����l~�Eu��������r��A��N�XH����)�"���V�VU�����2�n���l~yE"��Ƥ�k��A@ �M�9��U�#ɿCm\U~�~%Uysl�V�M/vbW��2�U�3P4g��' '����5�A�ߛ=���{������׿O��yZ����+Ȩ���f���#�k���_��-F�m�D���E�omt.wwS�ʗ���[Ӥ*��[� ���ܼ��m�"��Kw�:���&���*���ż�$r��@�r=��6���s�^�h46_�W�*�vO�ܭ _����0����^�6�}��rF�9�����Uގ�Ov�ر���#Q�&���}'��5�Y�_�zu;�o��:}D����h���?�;���r�K�)�U���?�1D]k%��Q�K�-1��_������,%W����g���&	k�cޢ<|��V��o��m�x�TZ_?|��5@�d��w�1 ۔Y��WD�'*w�A��1��Q&���4�E?"�A��<c����3Īt�f�jR��晷ߚ��،GE���&wݚ��ڹ���~�����J���uՃSD�����&�w�s;d8͡m�U����#l�0��=l���کc����r-(�����s�[-�F����0��g�7t���{���>���MW?G�u���~�u*O�D�����l��=�?�:�� ut��V�Usi��N#�;�#��(�Jg7�����yd����\D�D}�ZT��
�V��J��H�g�Fg���)tYL�f�*�CPy�a`�1��mѽ>-{:�����ւ�>0U@yǮ k9I��K�����Ǟ�X�ž��il� �}�̅��>�R޷���l�o	����@?�0��n����.1����ǼĻ�r���w� )Sf��@���Hfm�@��q����,�>����BZ�0M{[�*LkI��#���(�c!s0�7���}f��e9�W���Xm�
�-�� �l��6���E��'�+�.��A�&�z�W[��gự��k��C��G@P�>�_�l}�e�h������S�Z-/���O4�Nuol:e_Z}.��l|��O8���U�j�[1����8]���a���Zb*k�%�tK6�����8n�Pcs SC>Z~s�x����� Ҿߞ������2�k����XI�S�۞T�w�������o;-�1z!����)��i��/�!ICڿ�r/w� f&@�y�|^zI>�򧫷M�}�<��j���x�:�ۦf��l# b�=8�+�q��Ø@�0���^�'�"@5�c�G�mG�AZ����������e��XmP��-��Gc?���)�S\X��ڛf�G���x|�[����eͻ��;����K���
�Z�<}���Y���������an8��3u�QҼ��!����[��?�˛�mUE֑��Ic��<?wI�l`;u =� �}���g��Jm�Lo�z1Z
�mf/��:����A��lf�K/������Dh���8㜊�{�Zu�� W��"θ!oV�����]n��PQ��겛����&���['�y�)������-g���̓c{>5�Co�Xk��\�VlPi?(�3MS������~c�cw������߮h*[Axշ�'�3� o�����l|��Z\|��K@x�z�
��f��lww��^���>�����q������_77n��ǤG�w͸�ɦsv�:ә�zj����i#��n���v�r�c�6�=a���ގ1�&n�Us{\='ؽ��+=��>jБ^�b�����p����E�a����ș��w��B_'�\x��>�6��ﾕ�V��uP���'��TsR�������<}�������+�} H [�<H���h��4�W��RXg�W	P<�u��( :c�w����<}<�-����3w�����t��[�9��3����6Oc�p�{�@mzG�U��{���1̳\��~.�om~�]Ӯ���[-��6;*���j�f��fF�[��y���ºUOl{��OC���AH�����RS�4�W������� Q��s@ۛ��:��":�5���re�wc�Ͽ�,}i~�)v��	[����Z<�@1Ov�jܮ��¨�M
��80�h�{�gF�ͧ@$�]�:��i\u��Mcٳ    wYѯ�0�K�0�	��܁ɞ�l���r벒���N�j�X_��`V��MI��Ԋ��!��K�_4o�$�߇��;DQ��Mk�3&S+��v�~�\{L����B�6�t[/c��Kp�@�v4��E�"�e8]:%1��4��R�(k��F'ޚ�^���l�-)��#^�L<����h:�q�
�����s ��p�ř���v%��Ar'�֣���z�l�.\�5�'�A�{[�h�����k�vy� �7z���F�b%H�W���Y��d�P;�����v����;�|jUwGY�@M�3��"Xk����SO1"!��Rp{�BzUg�sU��(Ŗ1�/
d��Q��n���3�9�A���H�'B��S{9'��j���OS{ܓr���m���{թ�N�[���A���*}~��0D:�5rl֘�{���D���K-��jF�aD��4%�_�r?��G�oN[z�����i��������_�-4�{;ۤym����7w!{&��ğ�Ȥ�N�i�2�y��wS{߿�-��(A�IGo��:K�c���v�;�a�����q?�H���{_Զ���3�7�����9�����{ h�jNF�g��&��=?���W�s'2�zƬx�u��Sp|�x�)�xW�cվb�E�֏�/0�эz���)ŷ����X�k4� �x|�x|��Ľ��4��/U�$�z��Gǧ���T��:�����������i%�s����t~<|�N:��K�Wm����t��߷����y����W�Wh|Ƽ�R������/�*_������i��w�,�|X�����Y+�?���އ�i���އ/i�����_�_�N	���pZ����pF����W_���'�����<57{4>�|x�,�>?�^	��r�O�]<��i��k�޿�}�����{!8P	�}_��n|_��I���:
Jx�4��Z����Iɹ���*Xi����������-!>��O*^���B�#�?Q(�'��?o��7�omI��hx��҆1x|����H�p;��6��zx��G����'����TCi���kRi2���S{<7z����7��&x
}v�^Z=����<8g��mL,M%��t��6v�ch5Dg�Ք.	 �z��=% ��n;����TW-/ �_ ��%tvY&����ӷ��pBڬ\0>+��ҏ�|p�F�c�mCt�����/�j��c%|��Q��d987b�'�0.���I� �	��É�E^<�uT�xxq�x+�����p	���Ἷ��}���\yx�$-]�p�xIN���zPR�o��j�P^v��eΐ��G�K��56;��f|�n�.L�����/49r��f�%�����/Oz|]5'��U������s����^[�nt_�������9��?m��{������}�Qx�AС���^��e)�2��������3賑��/�������)ԯ]5͂d!F��Jv1�����v%�� ���=���)/���yoV�9&���)1&����$;��RbL~=k�~I~�i+�8�$kA�<��Z�,���/�~ ��k6I�'�d�$?x�O?>�����~�d�`�׳����?oV���gGVx�҆ws��W�<������k%��~�ϋW�9�zQ���I׳�S:�d6������_�t��ߎ<�����E�r���k�oãI/��yRx�0/��)�Y����J��ُ��ٯ�\��~%��6��G�� �!i��A�BO�⿯��6��[��?�?�dv��ͭ��ώ���w�QJ��%/B�'FD�tj�����a,�u��U����%	�R���{�"��S#�d�l୭�(ך�@���SK��j���J,���t��&�C�%�^��p��j�!�E�]�w�� ���m(��,^̭6���~ _`�/w��v ��N�@�Ń W�P?�TA�o�-�GG�������xx�߁A�E[� ;��[{	�;St��T�յb��GϏ����^�6qKf?��l��yxw�8#Y�g�'9
�=���r<�|Pv>x��x'92�������q��$�?��|��%���IK�Cp�xI���zN^x��}��oJr�����~�,}��%p�A�,�����N0�A��>�iG����`��,7����^-���G,7�����܀'G���KL-�w_�A4z����q��ẞb;�o���bN-�� ��(;>��z��o��s�zn�C�cFP|�ӑ#�R���%Fܠ��ws~O����J���/�f%����Y	���sp��1�'`+�7DA�e����?[K�C	?#TC�b�3K��o/5��.�J�4�<k'n�5[��~�|��H�Ob�����*����l��	��f�np�d6It܀��VR��s#��H~H�u����+���L�S�px��ŧFNKv�)J΅tv����4)��	^�{���]��,����f����W�����j�4�m��?o���r��r�#z�����9Hn9��A	�C�3� �/N���
��;�I���V�A
4^/$/B�?�P�O�~D�r��J>J���:s4��l��G��&\N�c���ӣ(���i�ί��_����%aI2���s\��o�<� ����O�xp���K�p*�s�fC4��!�e,�k^�|�o��b"�c��b�ƀ~|w|�!���� �$G�[���qO����p�8xc�h���=}����'�� �	���ER�;xtZL��"�����:^�t={���d' ��.���	��W�GIno^�����J���R����$]��-�������\:vA<b�c ՛�Z�A>��,;#TǗ�C��h|�<i���Z�ib�C���]��c�x8<	�6�gG�� zn����97]��0g97_�ܩ�ʹ��K�/����ch}�����[5�:x_���;��p�k��d��:��7���1������$�>��x���w|<����r`����4yώ/���h��F���ٽ�����-Fx�#;>g����y�\0H�y9r�3��W-Dnx@�c��O5+��c�=�Oz�H1�Gp*ATc��%h�v|�������߬�{RlL�I8Y�����0�8&x� k#����F;>�-�9Ղf+&�ٕ&$�~�NvLxA�t��ݼ*I�@�o�q��b�;Pg�%7�����҆�������^+����<k$���f����z����S����iҊ��S������
�Iz�ޜ�u��d
.I��	�C��������FaN������~p�x��џ�Kz����N~>���>�b�'���	�G�~����K����J�4-}_��(#��i|_+H�KBw|�����GJ�I㍊��|��VT��|��t��  G�v6x�(��W��煓�r�̐�`mHы�gGI4k���*	��~���j2p9�Sō��};?G��^�{�34f/��xZ�M�=����W�Ӌ^4�ի^4�с���v��S�u_`9��D_/��Gg%V;��y%��G�^o�Ē��#}b�����p�(-,��O(�;���%E�vC�+F�qp7̢�j����E��
�\D7.�b�t����l�<�L��$\/n�_�����He��2჋���'=�{T<�R;$���N�O��7����������s�J�rt�Ϗ���ậ�����=C� ���H�47L�nR�+I�O@R�ܮ�E�_�����&e.xp˗s���3:|��_��v�&xsO�%|xK�ȃ{bw���s�Ύ�ܯ-��
0;>d��
��l�K��N=7��[���\�ȩ�:9��I�Wu���[f%(b�sK�0�9F�fVV�G�$����~<��܍	]e�_7�	ݔ��	�y��a1�?oz���e�O��>g-(�[��	�`c
x|�.y����$xxe����U�+��l6<>�� ^8�F����X��t�~    ̪���xX�8��eeV�r����J��^���I�|NT����6��ng��#t�'�2��C6����Q��D�V2�2��Oz����V2U�7���G���>
�����a�?�7
J��M���[&ge� �Q'���h8)"�NÅ=9i��zA�m$�7�	��E]��#*I����l�c�r�L_��'J��?b��Y���$�X��5�������a�$s@GWϱ�6��ћ�9Z�̲}tn���i8� l=��Tʚ ��pN��	� w|��sI1� @i�����)J)�ëU/�wxU�R|�)����K��CE��n����%Q7��Y�T���hI����ފ���T��\���*A+����Y��J��A'YKyx��� �B���⹦�����y�鐇���9>����/8���'�%W|���}�R]#���%9���S;KJ���ʀ=��$�i��RiŇ�U<� ]<ϐ�*�/yI����D��̭������~�T�pxZ����O����×״��9Q�ËWӰ�<�wV���4%I�N�/�T�������s�J��/�O>~�ץ��.��]��:8񴤍}�C��%8>�Xoˆ+�J�i`E����]�:2Țkި!z��K>x^���U����� u�@�~9�r�O��ǈWL+�6#^1��Y�;>t](+I��f�FMG�뛕�Aഃ�����e����䵬��%��kYZ=x�W������&���*��I�<s�:�'=��gA�ܪ8K����6���3�&H��J4�dk3���H��/I�,���lE��Y�����m[�g�㓮�Y����r���TpJ]vFr<�[Qgg���f�NR\*������|Hϯ��]y�l2)|e�K�
_��Rx�������o��t>�n�^H~���6��B���ɰI��i�9(�����-Xi����v|����s���3�2oR�<�(�ӷ����>K~9_��B�>8�.G'�m�G1	����b���3ʘ_	:v~�s>&xp3��X���TЅݧ�����ϱ�6�����hXxվ��R(k� @I+hᅃ���Jद�"�	Xx���H�^;�~*>tm�کzn��-J���༦���w����M�0x|c�w�SA��E{i��%):H�<:�(F���� V
b��[^ވ�
�$և��iI��m'��y��x��z|❄��x)����P���g/���t|���S�RAW�J���<�mKB���񒼄O�k�5�e�/q��[MZ�Q�<>�S�xx�{?��
�~��9�m�Z�l�x���e��>��\��}�\1'�����P#��+/l���\�Q���Q�W$xp�P��K���>J�\h��!��BN�F���廏����^5�.4��K��G]h��xI���K~?��1�ӑ�e|�S�~:���٧�/nLE}J�E�E�}c�A��7f��o�I�J��_/x|�|ˈ���Ԗ���J`cǘ����_�O=���1�IaY	j��ର}���������/ZP�������O�����KV ���Yj��6�Y�7c�]I����+���>��Kn�L6����68a-�(,m��U��C�[	<��FZ?������W�Y/���I;>�M_M�f|��!���;G�	>�I��7Ǜ�L~|���͝�'�.��t�)|y�K��|>Y�Z:~~�(�O�͆�N����Y	����=5+����u�/����4ފ+F�I�A��x� �	h|�/HV�����I�O��雳W	��
&�I'���چ��As��7���E�i��kkQ��1p�s���\ϓ%t��Z�l��x�C�����?�dD��Ԃ��I�eP0���x�Q�l��t�H�-ܽv�7V4&��{���H+w��J �Ifi#:)��iф� t�/�T*J&%��e�4p|Zڀ^v)�x��D�/H& pNq1����}����*p|�O��&*x|����ӒK	��[���<�h_��B�OQ������!J�ϣ�V%n����lU�x��ג�dS���$�� ���P�_�_�
<�BN h�E�M������|���cck�C�go��t?���ܷͤKԘ���� �*�����Cm�Y��WﻓС�^����A�J��5�y�L�J��^_�Y	<��]�Ԭ}xK�>/�'�"���|��r�5�V�^�b5��ԭ��ȲK��x���u+A���x(��Ύ�g�+j��~9n��
��6G���p^8��ځ����dǀ��O*f;tt��0�+F�\Z	�c��V��
1�{�Y	����sV�x����sVI�;���ޤ���kiA�NJv1�[�Y���4�� ��	��)����l���/���!�f���J��7xr�����x�!+����Կly�	�o�����f>N�˞���I���m��t;+�����7��`��^o�������N���d$|p�L��^>@-�$��Ճ ��i|�9H�Zm��[��@4����Wé�;>�m_=R|��Ճ 
��ͷ �j||����QrC2��>I����(�y'׆������/i�{�?�x~�~4I�^&��%)3�<G���y �gپ�3����$���̡�#,�,��Ճ7V�#�t�_=�n��I�j{1�����Fue�<����� ��,|<�P�Yx���� �ſ�$��p����81f�������%9�8��O��3��h>���F������{ �z.Z���{Z��lK��d�t�|L܈�5~��M=<���I�s�Yg]�Ħ�A��W�.'�%W|$O$�<B��o��(��(�$-���:*I���+)
�G�����u��_��� ��W�e� ��+��~)�B���ߕd��~WA����ߓ��8��gv;O��_8&|��C[��Ox�%�0�$�p|���|�Z���~�3}����神���Ǘ���5k%|���c�\t�^���sl���>5���`����/���s�ŨСK���#����&�wer�Z��~{s�ĩ#�d�3;��/笄9=�xd%hb�+��0c0�_���	������Ա�|� 9��7���P���c	����	n��0A<&8� O~��c	�2��^X�:H�4��Z�Q:�x�+I1��)k{n$(�6x�(�H�TХ�l$Cx�(I���+k�
�ߎ�~�H���#kYrIi���	��R�m�����$�ऺ�d���:-��Rx|��^RpVDvN7dpBr����!�
N:�^4���������*��/I�W^Ȏ����`�4>�J�_4�x��Wx����Ӱs�v��0~~�9Q�a�����pVq�ᤎ�����N��%J���~D)~1xõ(�||%C=���I�%p�LN�����
䤄���߷$^��$R85��ޞ���l��gx>��9Ʀ<8���7$�<?��qᕫg���VE�*�3��$��w���H �N�;@�����1��!��W�,P�tgk��/���0	_��߷�^���]:z)J��0pxӤ��-~@������R�8>�%|p�Z1I���Y8�z	��\/M�r��3����tZ�l�?~���y��Knk�"� ���Gp����zJ�S��7n�Y��'HI�^�̰�� �uIQ�aCwΫa�_���Z�XL��le�^�~4��[���Eo��/�����t�VS�3��+z=ώ/��軖��_��u�/��QQ/���!<9�/�N��
|����G|��q��l���$?����� V��o�8+�X�N��A/_�l�Ƞ�O[��:gGtf�9g���j�n��GY	3�c�;�f%
~�yG��F�^��f-��$x�*k-	��u����3����S1�~��ų��p��l%F�g�d+�������O��~N�
���Na�~�	�
    >& {Q���{+�U��s>xa({/��푽d(���}ؤ	�x���s_*�į�t�h8�*#	ᬫ$C����yp+���O�3Br�Ã?oA�S�pVq������QKzFx�<G)�4_��+���X�1J���χP�K�|�)��~~��a�S�r���L@��ϱ�0�-���9�6f�%:8x����ryI��:xZI���>G��Y
���a�lg���Kxӷ*B%��Q�\J�A���*�%�x�J�g�S���ق�MVҮpH�o�(#- �w�9i�����$z��)�$Q(܏�Ln��O�����9�:�.V
b�{T,��F5�� ˽�J4���Uq<xu�8'��� �+i��ͣ�����:��^7���7H�7��ܗ����[�^����^_+I���~NI��n�{��E�Ts	��J+�P�%��|�45��%n
B��E�߇�-�贺�����>��2Q#��;��E4��h>&�j�ൡ~*܊�������YxpZ{Q9�&�[ngF5�p|)��$���j��4y���n*?���kn�����F�f�X�Dh��$�ˑx׃⃗%7c�����H�y|�D7�pZؾ��KǇ�R�E\p^<? <4��*���px{��ҶC�� �5�;@~@@�ɒ,��\6S�0�>ګ�T��:�ۋ�A�岿"���B�3�?�!�!Q�o;A�g�tw�(�	��r�M���W,g��4�S`� ŇU��ci&���x�$rpyO1�ũ=Q�pyO��y�J2%x&�6^$���2�CH98<g�H_䖘$M����f�&��%'�xp?���fI��o����,	���?oᅧ�	w���T��f�/�=�S$<z�W��@���N�L�>T<�L<B�b�A�/
jސ� ���1��ľh�������9V���TqS��$$�h�4|����Oq�sL �S&�y��K���؃ >o���'o���%7E-�7�����:e��7�_�4|Mv��b%wTx�/&����
�|�`E�_�zc ��n�_�:1kY
^�.0w"
��d/bx	.����(@8/s�L�N��1��t꾧�?�p�E
��d��8� ���- A8;@f�E�S�l_=$ �!��Fn f������3t(@��笸��1�� ѵ�l,[A
����� h�^�����^jS7>x��1xA�S�>�%�1TW>x�ie&��ڒ��
�"@��1\�M���d7�J����G�X��殻Yx�-������0����q: ܓ`O8_�� �ǔ�<nO�گ�'t�����)�ﲛ��3�a�(��r�G1n��12Rt�͍>��#0����|��K�3z.G��&X���ʨ~@��/i��_@xMp8SQ�x�w�� =^��X�x �WWi�; ��U�qe��d��4���d��M�U�Q�5��*]�g�� ��f����:]�gB� ��f�-ϖ�c� ϖv��
x�T\��� �pW��N�(^ނ��W�h4 �w��g&}@�(� �
��̦~ ��H`Y���Ls*g�	l�)���.2�� �����? Ŀt�H/I4x����eD���9]��=��b4ឯ��,���X�褆�3��ҏ���2?K�ٙ�z܎�3��,˅���~��dH�<�E7�"����Z���ۭ;~9S;8>>���y��En�F=�oo�\UEm���]�˒X���U?
��qg���� |1ӆ�~���5�Q�*nO;�Q|��>�;�*�'w~p��-G?
8@ý�?
8@�b�/���t�Y\E\��.k�wbwQ�ė�b#5̀�\�gt�a|��#�~�t���sL3�qk�'1�!��L���c�}�Xit�@��l���阁�	3���h�t��1�Ԑ}��e��j��J��v�=���5�f��k0�W:b~H�d�����$9�/m�$;��y�;'�)�S�l⋉
�0~��,��K<�Q�Fя���&� <#��+�� ���p�yV��
��H�5�?
�)�o� ��D��h���8ԔXٻ�`�.�1x42?
�W�~BD���yv����G��c���!:�����O�Kž����[VA4|��XK���p�A\A������or�@�u��)�G�ױv~��a�<�gX1G
t���{�/G
�����~��P�W9�MmQA��:x�f(�z��7E�"D��*hQ����%�D�_��̔�%��MT���w�����T'9DWv��5�w�3V<$�|�'� <_���$�+��ɖ��ı�Σ%<V?p���d����H��[R���g��ђ��I�w�J�e�)S`R��������p*�P܃x5'x9:R���Mt�3�J��颸#��W"S����k0���/�W�X!�_�EG
�_m�/�#�n?�M��W�i��(^̑������Z>������v˥t�t���P��]=�5�Q@��([t���5���K|t<�������>���Es)6���sF2���+(>0�5�@��9N1"���Kܒ����%+^�y�}hж�VUCHM=� B��7�z�*Q��ᛛJy�� ZiѮ`�{�iƢ-3� K��.t�,=>�I�ű��h� �����>�F��� ����ԃ>��WQ��~��K1 �;�շ���#P<��T���7� �^�Y1��ী���3L�4���`V�(f�� �~5پ����GINvp��O�
� �� ����'q�4��Cg�ecE; �܇l��t�wٳ����.{�J���.{v����b�_�b��Gsy��3�8�U�p�j��.B����cRq����qJ�� ��.�I����օ�pˑ☊n���� -/ Rl4���'ʠt����{CJg8@7[�LJg8�8�� �s�?Ƅ�iu�}:�w��Ȅ�\��@����>�f{��8K��p|�Pw�bG'V�IWyY����b|�Q��E�8���M�������#^�����O�2��6J��+h�v��[`�9��B]<@6,j��z ��e���x����<(��i�D%1�!�xq�C^�A���!�x��#��z�)��?lR��P��G��p���`F<�n�W"[;�L�/qd6���P�"��Q"+��2N<@�!��Γ��q��$�3��<����0�$Th�ū������O���Q��{`���y�>!���]�V�N��i���)��Mw��X0�b�؏����3�|��xF�Ͽ<�B{8����[���6R�=�����Am�N��>S�ó͉�r�Ox7�bYa����Q̎�Ɖ�}���� �����b>���}~��ܯ�(���1ӥAq��#י|��e�n2� �����X�7��I��ؒ���)(U���L� ��9!��(��<z�w�Pt���bV�B�BmG�J�K\��PކpmF1�q4U���a������I���'��FS�s⸇� ��AtQx�[b]�����J1;��������g��`|q����'��A".P��İ!G�)`V\
KL�J2�
!bJ��d�bX#1��[�e��X��5���G�S�pN���1�8@��' ��oY��3�k|�����5Љ+w7��c��}q����kp���ؓ�|������ۋk� �b�D�0��#���r׌�w~:�|G� �h�/����f�1J�tAh��K��3�t������-hx9p����������9#��=�JzaI�o��t����c|�t+�����M����+��G���o�:J��k<J�����ڂX�Q�"�mA��/��Ķ��D��|pW�N�v��Q%�p�R��;xŨ(��]Q�����4g��E�*����L�T�Ѷ}���T�zBьH1ڶ�s�bؔ�ѶP��A�.F��Q��m[�     yu�m�d�Ѷ~�oM;��¯i'[z�+�ŋ�V�W��G�xe�x1�
x�_�^�DO� ����0��-�{0ȳ��sk���e�(z�E8��D6�x�f��o����m�/@Z�͗��K��)��keϙ������tfoX}���r�I���|�Wz��+��^6�A_3#M�ߠ��1霝e�>��Xd�g4��ŇoUt�D8�X>���R�Ko���Rc
x�Z�6�￀�X�/L��_ر�s0~���\�K���"LL��$1'X��f,U¨2ĘJ�W��߄��;�'�w���F�����?q��'!���Jq������)f�;�>�oŜ�G�_`y�58S��!+���p�Fޅ����O.�u�Fg
�)q�B=��g|x�|>:S�q�WK/j����sz<��|)�+X9�a�U$
_�ܭlp��c�yx��@#̊w!k
4E9{�E�)�oqV#�YS�z':?����Es�� �O�� ��s
] �.(	 ��M|�(& �+裸�-���C��|��g���}�0�qx'�$ZS�s�l�����pVO��[�Fњ���6�9$@�'v��KG�3�ŭ<yr2k
�C2�'3k
x@m"�� �����
@�!y����<��>|�J:R�0c�L�+�1������i�3π�z8�����`9vI �'������Kp�$��x/?��� �!���k-���?��E�t��`�}G�x����Щo��߽�M���>������i��p
NV��/�=����Hk0�x��2 �&q������
�1�������1 �)��8�{�WP���Ƀ�6�k2Es���?�N���f�����&x �O���
��ň�/l7l~����Η
#(�.�-([/dr�{��s��Z�3)��=p�F[^
�q�'���_�'�o�6���%0�� �11��ѿ~F�(D��)��H�k�"��< �;�E&��[е���� <֊��_�3�J��E��G�Q�#�6�9��ڻ��Ss��z(@�|�\��_�G,��H��(�$ųwd�����U�G{xm��.6��@���&z{�c�ľ0��d�.c ����H�x�<�%��y�l��᫾�?P����"9F�!��@?q����c"N��o����<�+Ӊ��5��R���++����a���������b~����+s�����Ȭ�>�z�����D�(:��K��ѡF[�s�d-��{/��O_x>P_8���~�t�|Ѥ��{��v�� �MD˳������`���ƫ���}fn0�z�_�l<Hm=�}��κ�ac�� :��J��w�x֔5׷��C�_��;@x1�� �4][�ވ_n�����˜^Wt(�M���N6�����-e��-h�������o�i� (Z���8�m�!��޲S������M3��W��L�= �?�6�=H Z�S'.����'=!�����f���}�s���h�ϖ�l@7���~�Wt�?�����&śŃ����	 �{p_B.5�}ܖ�����������{J,٢88{?��*t2�@�~��~�8�;�1
a��z���Îb����gK����t��z�?p��P���8\���K*J���>gt��dRFW8@-�$��Ԣ�^v�J׌���-ju=<c*f��KŰ����:�.�H�ǫ����x��[��f�Ų�np̀b�H��k��$�Kp������"@�=��p0�y �3J�h��n����C��� �O�H�	ܭ�ٳ ^y+At��p�[�J��?u�����[9�_�m)��G[
�!�^�:#|�U�A\A|�-F �S7O53�@_3��8]B��L���"�&x�xn��h�vxH�&���I��և�������ˍ���
M:�d`�6_TH\�L��'�TM6�*P[��-�;�Pc��-G��|F.&�����d������Qe�1��i[@j�?���RPc��N��=�Aj5�������_��_9�6>�r�5ī��b�ӣ��f}����P��
���aE���^ײA\A|�ӽʈ�� �1Z{�C.���`�o|nh5k��=����=��3��h�X)�3���f��ڭ3�I���Q�~��"jx�7�� ���s=,��0�S�e�x1k�B�L�)� ��d8 ���6�C<8S�N��LE�erw �!�XQs��oi�j�����J�oe�ň �M�m�3���l�h�g^f���� �@xm+k�_
�;���Ka��-���p�^3� ��'���s�T�c��r�4�l�tN��@�� ��r� ~��p���ؐ�-�v��?s�2�`������F47� �O����_��t�Ujm"��]�ݜ2M�p�o��� �����Ճy��)��GNqc^��ā��|�n��ހE��]�W�)F]�3� @�~?�J1.�h��߃�Q<�g�c��dgx��h%���)S�l��y|jQ5���7����10���!#�9�C�2��3���G��5c�4��~~�/�$x�8# ��#�C��`&�_:� ��#蜸x6Tm����g��~�}W_b�< #x��#x��]��n��C�'uA|I"~pd%���]z+�M���`dε�� ��= �W/Kdc�G�)�b��ÇR���Q�*�pel�ӄ��Α������88���W��B�D�G� ?�N'sA�W?^�#�#pxAvA�+�kv��<�R�U���bS�Q�8>�|�x�q�3�?U(��2����W� 0�Op�L�H�3�Dg���g��H�2�����9�����w�	�F�Y�C�]p�U������������ʲE
������h��zX��>�{�7�M�'���\>'v�'V��%�&=
�G�N\A<c&E >/��A
1π��lFH�3��Ζփ�~�� ^�lp�@ټ�iPw�/ ���:��G�wx�.+��� ��d�Es
x�.O�P�?�?$c����No1���`D�^����u��Ol,{���Em�h�I�l�����J\A�Q�}��C ����'�W���t���݋�J���;YE%ރp�Z6���=h��`��ރϑ�ꪃ�֥���j��ߗ|h4�_�XP}����韁Ɨ�N�p�>�p�!�h��G�� �?��"d��!:+.�Q/�pfc��0��n����I��������#�.{c�UH>Ч$G+Z��G�����h���o�rr^�݂���ٍ~����$�����
�|����PR��_�Mg->� ���ߑ�e{x�T4k��L"@����S��/�a3qF�
�'6J���I4�"�{t��Q��ᵷbD�-��o">�+bqA:��e���
pO��D�d�Ө���x}�� ]��4�I��_7�� !���o!���s��$9��<dC0G
�F1e��	���p�+3Q4|�~��{�
z��ŧQ�W#^|Ew��x�y�:h�W0O�t�A��f{��!��9�6V>E�@��xfW68|�_�;\ӳ��6�8���w�$���MHI�t)���:,�)o���W��0qq;50��3�𡟸=�R:j� /jU����}|	kaHB��h�W����*Y9�X�$e���X^0��xƤ�hQ��+Q���Ko�U�G�8@Ǫ��}:!)N�IQ_��V2�PxK5�����M�g|���c�@|m�
�g���<Ȩy�}�'n�6��f�qq;�/�׶��b�O�����S� �megX�r�/�|b� }��g�*��+�í��(��wq�N�
��8�Yd0�+�_��hP�
�`�/��
E	���H�&��g8�:[)P�p�����    qW@g$�%#
���/n⮀��#���J<$�^�I���{��O1x�>G`����1��X{��w|p��_dt����-�#2����<fw 4����]����;����A7�Ϟ���q8@7vH�n0Ύy�n�cdT��.9�� >��Q׵�=R>%����%�q4�b�{;�靲q8@$�����E1��Q�� J+��޺E3��(م4� {���ň2�� �c�)�h��H,�L(l��oqQ:�?j���^x+^�	x���`��Z_� o����C�g(3r訖�/`�R������F-��~��$��j�T�1CG��l�5���`�[&{;1&%�4ir��,pF)��x�0)߯z(�W�_��׍F��C�+�'t[7]Mp���X����e
h|��I��n��j��� �ou�m?!�G�(�D����������Z0�O�}!��8�iO���Gt�������&�'V���z�פ�#$�7��lԸ���8#4.��l-���<b5�.o���1��%�ڸ�\�F͈���������A�>#�s��!�a�"k�t'6k�b.�h���l�! ���l���p���_ͦ#"8���H� _i4�Qt"� ����l^阈�����c�U�
<@.�D$x�Q�h�_:�j5Q����ȈN8@�Y���\��ភ�����I��~鞣uS�/��H�O�D�ˁO`D8p���>1���b�.����|I���P�	�ߑb�� �s*��G� L8�6��tB'������ch�WYG����ş]�㊩�
�Dk%�p���h�ôV�M����O���\k�I�Įu���8��奉B.�[E�j�',(֊�`�C\�&��.�"�ß�����r:�!1�'��/w��
�ٗF����7�hG#@�KbĹ`�3#���xݳ��$`�GO�� �2'�o�{r'��pO��ė.��/���)S�b8����3��(��7@�������e?�@��Q	�5@��ފ8�9*x07Q��L�3"܍�D��?��b'~b<�;��#�����b�,{F�l,o��	���ffm�����W��]�t 2�/�n4������˨�F_2/L} &���c$l͢g�#R<�;������I�Y�@C��H��۟����钷���¹
%��~�;��8ۃ����������n�<O��p�G��w}����Ƀ�F?$J|��w�Gxa>��w����m�:@|2Wk�%�#�GA�"��z���Z؄�~y�&^a�	mގ#ҿ/��]���@4��1dQp|cU�݁p|���H�w��Qq"��Xs��4����$H@G���H�uxhko	�OH�&���$�Ø��9Qu��%��|�3,'��,J���|��䴱r�v�oB4��q҇��f4lA8<FӪ��}�3�l�8��d�~H>F	]}����_	�U;���a��,^�t��$-���;5��?Ck������k�%�!8�����X����_8�o��|�ᣓ���M_?Ps}�_�N�g���=���S����?op�B��C�s%�Z���ͶjIt��,-�:���6���͚����Z��7�C�i���S�՟�_ǥP�~A��~ܶ_;�J+���ݹ�V?��H��R�C��V��^P�a�T
��E�iB�6��kgb_��6�ô]��y�@��'�N��yڗ�=B�����D��0`��nT�y�]��H��~�+ָ~U�5��	�**��)���n�TZ��f^�j��q�_R�<b�})BͺC�ǅ�����|G[g�E�u��gj���K��@6��j�ёVn��ʦc��g,�iZ
�h��@����m�odQ�gOe�Ϯ�����_u��ru#��O�;g�M�����\@U=J��J�{o��?w�R�Y�5�ת��^RU{F!=���[�05 P��4+k)�X����OU�.���x��K���ՠZ�����J��#�ST_�=���.�;?���M���˾�kݟ�� ���KC����^U���C�+���2�?�����lm7�G�F����_1��Vܔ>C[{O!�����e����t���)�6�|��~�H�}��\�UK�#+�K�T��1z�p��t�=\���h��*���1��5���Ա��?L}�Ҩj;ʋj�J�*]��}QS</*��+-������o4]ѵkmۣ�s�A����?����=�� f�hݣ�XZ���=O9��%�Y����!�_���Է궷u�5�Ow#�^�1���3�s[_ĺ��{�<$<T�y�9���,Ht���a}'I��y�p�|�@օ���1�&J�+����ulg{���`o�n7��>�k�
ƶ�G�wQ���k��f��6��xë��t�3���7c��c�A�0��	%���{���ysӮ�� �
�o�u��=jw��q���r �0t����v%�_���V��iۺel����Q���LM���H�\���l�7_z��0~k����������*���G����g���K���R�O��ыc�f��r�d���S���V�;y(a�%�r��q���V�u�`��n?9��ĥ5���ϡ�����k���H�����hw�^�{\{�5���՟�oӢN=�#�W���C]��՟j~��j��3ӭ~d ����œ[�3n����j?jݛ>#��-���5�8����{�sy�����~��8��(����-��^4�c��n��������\�.�]ߋ�D���Ǉ��>UV?�u����D��h���Ę1�t�a��BX\�IZRU?xt{y���ǿJݫk�j㍃�S�@���5<�e�������15s�sl��c�z�~����p11�+���G����j+v��(�ꇠ�{8w�k�{wu;Ɗ���Q�~��u�����:lNV��v��ʆ��Z~����MUUAUK�w�(�:����!���E�FT�(}�5��C�����z��ս�6�zp�3�uO�KJ��;ܞp�h��+�!h�Gn&Nm�����3�;�Z|UU����Jܯ��Ζ�Y�:�i?g����n�'�-_�g���?i�7[���fZ���.]/~/�����q��aV����p1.�[Mb ���ot��@hQ}�a�C����u\H/���t���[��Uǧ/��:pw�C����/��R�� �Zx�!���~��չO�������a�+����tOfҴn�[\�����:�M�\���>�Q�b#Ն�V��J�x���~瓞��w$��nT桶�i\��"����ocSێ�8��i��9{5������*��>���Iw����kv�����<5�j"^��g#�v���@?K�N�;��w(���d������H���%�B���.�;k����������7��j�NY���'��j�X�z����}t%F�VKI�i�������g��}CNm�J��2<5�{H'C���n����5c?�Y��f�
.��b�Zlzl5ؓ�F<�A(����7�_����*����F]�%[��3�=DNg���l}�]��?)���������FA�����iqa�qE���
#��>��\�ks^�H�;��忩g�Rw����$76��  P���K�n�����6�t˒܁�RH�n)#n�����>]=c�u�>�N��y��}M/���J���9U~�� �G�SOa|/,���Z��>��g���$�ڙ9L@-�>Wq�������:H����"���xL=t���5�;H����9��2�x��j݅�G�9��QU̫j*����l��kRi[a�:��=��_��x����?���7�}����j��?X���s���|Qô���O���ܵM��"㵠+���x�&��Bʑ��D�K��M/�,�-\mD�Q���YL���i�]xv��ѧ��̱�>�����i|��]�Һ\[������Z���aD]��t���ѭ	g�am3����f�jd5[o�*d���    ����]J=a$-��y5�A�u��꥜QuW�z��"��b�R�+��U|��aMm�����ݾ{�k�]cQ��+��Y�S_�.�8{^�_z�뗟��˾�����㿺`�_�����W������� �o�6��U�zl�϶��Nt�'�p�xT��>��'"��ހ�K�ƞ�����cs{D��#�v��`w��n����v���!��b�v��*j�|���luOn6���U/�p<8��uW���>��nU;����T���>#xoU$;��|�3[������aeU�\\���D�U=it���Uִ�QeSZ��芞mû�a�B�^��;��?��K�S��rk�5�=�hO~u�+J^m�J����	�������O�D��bk���t;�P��s5T�D�������U��u`ui�E���N����:������lv��96�j��y��Uϭ�V�f�q�"��XO��q�NƋw���9SC�p6g����d��	z0D�������}�����"}�j<���?�x���I��_˹\��"�Z^fT��:�%Τ���U���n����C�m�dC�Fu] PM��0p�ˢ����eK"��zړ�ה�dT������?��?)��#|�g�y�v�K�[�V �Y�����k���Xٟ{;��R����d��RCѽP�:IۤO����(��EN�Ž%�xY]���J�U���f�3�F�JK;_�wl��J5�Ɵղʾ�*�k�+O5yvI��Z ����rp�N�D@U���
�����pycn�[$F��mԎ� ����-άU�`��\j۱Va��4a$�9�.FB��U�Վ��Y`'V�JqDA�����Z�+�ϭȹv�ș�KsD�ka%����V��rכ�2�{S�������h`���W۟���5kJ]�	����������IS竖@L8N�1�l����d�������a,�;\;ŇC�j�zk:"�d�˔gugIϝϩ�U��9 �eD ���S��`>;��Z�*g�Fb��¾�+��R�}n��"�ޫ�泒��써6mCT��ק��a֦�.R]�Β��{����
m�6�C�'��/|[�N\Y���uk-E��}!�jk��^�ף<�b�SոxO�o1R5��g�s���O&M�cҔ?{J6,����簪���<w�3��4��w�(#M��]�N�����(qV����=�[�U�,�lF#u��������N���ק}���S�@�P}��:]�S�c����]����p���S�W-����FXnp����4���>�P���ק@kBR���F�M�Js�5��i���5�T����8hX�a%��zS	wԪn�|&ֳw���������b�>�gԵ���w�P]]I�u�u��Õ���Y� J����ѽJ>�MB���5N��Ij�y���U���5K��ȩm��Ԣ3F�����Դ�$WR�+i����C���kngSg^S���2K����6���-	X- vrsK�w�Q�އ�RQ�I�F;J~�7��ι{�Sr�Cs�v2�L�^���8�k�)�q��!r�Ś�0��jSS�����q����(���eG)4�J�.ԑ�g]qua92*����z}��b:@!���䪩��ζR��M��A���'&�5��Q�$nt7������������&�S;)N�\-,���I������msh�c���E�Ӵ��d�E՝����>��y7�i�*�SR����|z�)�G��W���%Э����GJG����Mx�T��j�Aaӗ١��"�J3��!y�_�U*꿽n�W?�vMݑ���pia�|�K����\�7�����'&}�#h[!���z��!R�������C;ҩi�tst�
���}��Wk���m�G'�r|�(���SGO��5�~էB������I��ҟ�>�/��z`+)}���B�b�;J���§Xc8�=��h��[_�
�R:|��ʡ�*Y��U����L�
�*y�S�'����
E������X:=�:�)n�Eu���ZW/�⃔h��L�����SV�����>|�/|:=����Oe�e��խ����#�z��$�����/��[�^���0��%袦���55Ֆw�c'ʵ
�bF��N�t�{�ܯ��¹1W��zg������te���;�ϵ��$i���Q̿���?ZU`07�}�ڪ֐MmO6��叶�%2�m�m�ɿ�R9E:u�'|��-�xp�o�=��"��кtw�^�.
Z��'u�"G�.�ZI��<&]�Q�vX���/�����K[P���TQ~��1?�O6?��{9\ǮA]�X�/�_�-��Ǟ@��p�!��Z��M�þ�z���xkiU���tiT����Wc��S7�
�i�V�������W��a{�p��<�W��n���kH�(�QזS���<MM0w�/����_��	���/�&X�b����
�|U`&��٭Y}2G�T[u1=�5Ka���~��<x�2��{(E:n����<�?�Z��aڟd����HuU�S[m �);e��˻���z��~�SW��;�P�L�zt^%�壩�u�~��mǝ���5�q5T?6��ϱW�i�2��*,�`Q]E��{�zR[��Oj8���;K�jj*�d(�@��|T��^�o �	�ҟ7��8��z!.^���b}[�����T�Vzta�����tN*���H��^v��~�_ i�s�25��q�^`�n���ƪ�˩CV+�8��4S7'1X+��+�2��ez@֔��j�/�n���P�����X���c�<2Qw��i��5����a/��I�w�6��=�>Q������Q�L��=���h0~��З2�S�q��n�v)���`��G�N����$ݦ��?z��|۴���ߺ#Tw�=�*����6��L�UL�o��Ѕ�=1����.�_z�~<�1�]cW)��(��K97tnէq�R�0�5lKMN?�S���Q��ce6X�����*u����[�iI����w[��稉ڛ͟����&5W��.N�T�p,����n�����o�G�>�{q!?�a���>N���oO�'R��s��4�q����bڞ\�H��ʫf�{8�uW�.W^�tƭ�p���ܛ>)l���P�9��뫄���O'o�z��u
�����|��D�t��oL�\��ڇ*[.ZN������k;J�ˉ��_ɮlk������ת������QU%�͡��P�n;�i����x�#�Ӭ�}ʧY�6k�N��Ӆ�OL����M��wU�r�Y��;55�i�xd]7��n��S��Γi��E��9��;����O���z7j+#kQ���H�<ߊ�_ �"��*RS?a�O%تy/Xrq��ց���|>�+�G���Ѕ �*�_|�K.\�R�����V�G6���]��#P�5'YS�ɶU��U�z�wq�!���>�w^�Q������u�U��3M_�oVuQ<�"}��F�eBb�|?�K�~��l�t��o?�ћNG���L�Ե�b��˩l����[�߮$!�,#M��b���Ń����_<L.�ОNwV�֢�GoB�o;O��h����mZn��T�_��Ex��+ѩBkQ�%��l2E��~jk��?z�J$*6��ȷ��C�Z���,��u���v��\�����(�%��Ϲ���������3f�6�j�trҺ�A��i�q�4!����0v?���ї��b�t��ޝ7Ƴ���l���W����P4�i�Es_?G ����,-6w�x�X�g���Z�G���jtv��ǃ�n[ݖ� ���vK/r���t\oq��nO$k� }y��+.o����{��Z\�VI�xj�H���*�)v�>�����3ν?�W�w��|B������Ǎ���d��Ks�0���i�~��O���,#9$w=~�`е�u�0���5�a���6��?�Z��f=���o!�����D��6G�{;�(xϭ���%�A�9�u������W����Lώg����S���t��,�;N���#?Q��dꫝ����'G��܉���Z���9�W��:3�=��6mθ>���Cr��G�p��ƞf6������_��&u�yT�+ئP���Xo?y    ��Be��H��g����pEve����[�S��Wr��m�c�#�r����_���.]����2a����3�H-���e���d�Y�5Q,��g-!2���\=򧄅-���!�b�b�4%~E\�-_��I��ĵz���)d�F/�w�t������_e��"tj�*yW�\|?����V�%Ȅ%��S�o��B�Ox�L���p��O���Y��T��Y��3=�D��K���Z�,��5��ѫ�ꄪ��!��݆GQ�eN�{j\�����t���5t~�c_N�������Bg�?Q���%1���OWq��篊ȶ���,)�O��CD�O��^�#�����U��6�S��p[��{�Ủ{�!�nۣj�{9��q:ȃp�@���=l>W��H�~qx�6��8ub��^zt�T�P��=����v�'� I�Z�SgR��,6�Փy,m��qx�������]�;{��o��9Mv�֏њ�����/��[���o����ܯno�K����x=��p�*�������]�?�?�Ϸ�����'݇���8�Z���ǯ 2��=�����#��4c#F���F����??���A}	������f��d�l������[]����׎�|��������9�d����xm�����$�%�M��fK:wsc>��{d�{DuV��	�BdOs3�O_�r�<�e�P����r\4>�+'� ݘ�1x3����cJ�����1䯿>�̗�ͺ�!�떽|��?�yӔ��&���,?ƙ�op��q���3�%�1N�>���|g���ı����ۓ��g�8r�x{�Tt��q�c���{*��ӆas6b��)C�n�ϖ�[E�hC���+� mI4��V��1��:������t6�i��9:�myB����l�]=��OCg�����ݝ荒OCN�����|����#������a�hasP]$l�'X:�� �3���s��]�0.��}~]�	qN��Zrfp�'���sp�'ĵ�b��ĵ�cS?ο��>��ۈ�>�终U?�96��!�cS?�96��m9r!l�Û;Ǧ}.�N�@�I����������J���sc������k<�}4|�fp�N�lX�j��M�l��՝�����:p��ik��YO�O��OTV��^l�>vtnAG[��>!����?@�{�Т���D���!j���EZ�^����Qd�O�1�C�>@:DQ�)��|�|{�:>�)x���QB����6���a���t��m9�C��t��,G�s�9?��v��ײ�~t����+����'kO:�2���������_��m>ho���q7�� Öα����j�߷?���eo��r@�j�.��S�#�O�ϓθ0^�Igf�ֳ�����m��y��#Q���G����r`�FW:���8�M	[c�@\,Tf!��w���yL?�)A,�rק��f^!nN����xs��xY[��pK�D���S�����~o�03F}�	\�[2�n)��6[���`ð�,���[��\�t���2]���E��h�Q27vZ(y�ϑ�p+���yQ�:�3����=�!n������K
=��sl逮5�{��d|��`�6��d��&�����.��\tJ^��(�5�,Q:K��"�#�y"i��Qk0h Pʑ�l����ia�G$�n�)U	��5�����@~�����do�p�;�b�n���éq&O�<ß�m�T����?�~(b���	�%�!c��v�{�������� ��0�	7�5�-��x	�	,���)�p�\����������=���p^�ֈV(��p]ؽ�>%�ub�TX�����]�ӆQá�aW;K�|��#+�>^��k���X.x�e��d�]��-�c`T۽���p*=�eE�m��Y�v/#:`���K�H��q�)�y��[�9;�C���|��f!�ě�����񯗏�~~9�_���hf4�8賖9W�q�ua���(��'��Q|��4EȔ�&MD�s&.�6l��wB'����I��ә�2��22*��Ewy+N�eC���aM�&ʴwuK��,c�d7O1y\!Q� �P͔%���N��ę�&%H{
ᗥ�](�,��J�<�].ĭ�� �-ì,�Ƞ�e��	eȺ���볦e�wo�(�V�c�Qi�Gy�Pm Z��Pi���/"8����N9�}R�7u3JO��`�V{A)T�p�}�{lC��ݞ*-~D����s?��ǿ^��3TK�=O {V�����u6�C����oiZ�.��M&�i�8��m%��N �UXO9Q\�����.���=E�7�-�Cf9�1���qvA��T[X�����J�7T"k�0��`4��b���ņ�s�;r��t1�T��0�C^���t��F�NO� ��NdX�bӟsC����2�ԇ<s������桛�!�(�U]�|��'yT��^��$\jm��;\O�4m.��.A�֦ֈ1�-�w���@>���'��7>�^��g���,�%%a�-fzSE���Ř�U���I�M��+\�аk��)�@��q0�x�Ȣ\�
���&�A-����}��l�ԟ��H�7�����~�N �&���h1�$#W��ߒ=�������r�X�E�ʗ�����z��֕�P���č�U�;�����7��3�>`���*҇o���`%$�ך�˶L3:������>��"6�E.|y�S(k��+��w�,�I>���z�S>��X�ǭ?�9�'���:	`�۠�|X䠣��kR�)�����72�d��4������)�$$;z��t�s9ʏ���4��	/�6?�Sq5����|E�t�<��������\fWO��4K��>���
8��pn� *L��e=,��T�2*���ϟ�u\H�J�ټ�sp:.��Sp*y�s��Md�Q��9�����sި���z�-�ms��vf�6����Isgv�S�/�A�Mj�9s�Y���h�\
1��0���/�<��x�
����Aȥ-�mJ~8�vy�s�P�p�7�V3�Vw���8S:�ia�#��p�����B���v3�M�}dwT7�q�u8	fsS�-�C���Eg�0�
s��U1l���S"y��b��q�kW�U\,nPC..?;��H�-��lL��M��9;�9Lx��5���{�&����)L81�����[�_=,G�H)���Z4�Y�#,�+����*��µl��Y�NTX��@o�8+�=V�����5��䬝a���}��k[k|�I��t*a�\#�H<x	)�R��`�|$N�?P���,����b{�AC�w�@��d��.��[����Q���B������`��T�[�l��rɇz^�m��3L�����������UD�3P��!Ke(�k��P����\̿�KaB��5m��B��L�	1[N��DJ�l����s�	��5��Kڵ����hD#N��)6��s=g|��z�v��m��!P�Dŷϱ�!y��҇hZ��N�D\�S1�^�.����h�7��rS2Qۃ[Y�%��h��m�p�YNQ�p��*���	�S݀�Ǧ��ܮ�1o��mi�1���@�p�?XR6���+�K0Ѳ`�O�{Pľ+)�ӱ.0�t*�$:5$r\�Oεd��~���ږ� ���0��ӾkŌ�,sQ�r���&�I�#�ߛ��֖�-��$�Rw��mR�v�)̄�}K:b����R���s����u�=�Bf�F����/���t�?J5ǹ���G�d�vlɷ���_���l�=g������؇Ӓ�Ff^�`�(��H� �{u��r����f�.��3yYT%��8H��T�~�GT.5	f��������w����[M���/�*��{����7Z��P�ʶ�-(C	���+��:�"t����������%�x�ϫ�G/����� �� �V����ھ_�@#���/&t��݂�w�c��gvΙu��u�    2�Z�����ߡ� N���K���]0Y[���nyYB��ye���V����tY�-K�$En�0��W��M�K:k�N�[�m8�Sp*-���՟�Si��`w�&�K���Ǆ'��ն��lB�M�da���5��{N�\6	�l䩠S��T3�M4��З����G]�)L��&��r��r�Sg�u������&��*&ke��"�\1��B����j�a���P����?�Ç-u�吡+LȴҌ�7�њ;^��R:��0�8�o��@�洖 �gjߙ��N�Ҝ�O�ՌQ�q.�r毟�E5z������'��AIg�_u�,r)tٷN�iI�+i΄�� 
�L��?ϝ�IԄ�֤:���ˤ'�O^�����)_�R��ȇe���]],\-߸}TRU��DA�?gZ�0�qw;L;D����KU�-�"�߾���_Du�}���^���#�%�������k���;�ғCwNL�eHt�:�/���䴹6I����7�tўt��Bw˛��t��o��"�)8�ί:;�Ü6�^���*�m���~����\{�~�����6��>y>��F�����L�'=��j�¡q��7ح��;k:��ʝ�r|�v_�[!�texWn:��沒� �3�S<ƭ�{�:hӋ�m���R�f�?w��������¬��ղ� �lI)ad_=+NVx�s�A�@����3�u�j��#֑p_�Zc������Q�ؿ�2�}z�y��]"��׼#fըs�D��&~c3z��������Q��aY뼜S�S3�,����t�"rQu�_�jPf� 6�B�r@��{$�|�����O�Q(�ʋ�	��GגK��-���n��4�;∶a�����'C]�T�֌b��l.��(���Y�XkdQ/��ZVa(=�U�ߜ�n�F�rgq[��T|��e���ˇ�j?�v���[��9�!l�We1u���^?�����/�	����g7��T��ـ�Tj2���!M�m���
3�-�j>��d�R��mXxPC]�Z3}�fn=Xz�R����W�"�<�i#����	j��Ԑ9ւF�}�����Ģ��G5,P�gǑڶ��3@�w����uT�y��I��R$����m�&|��&�փ��@�����P�)p��-v��aH��m��a7R}K�&b=�~���s����
��n���j).(�k�>�u��'����%��A�M'
�bفz9����i�h�q�
v�FG�l���M#��>����9+��j�tOc8�F0���GR5�	r7���G;p�	��xЇ��W���?�Wa��9� �BG��|���v�#d�d���Z��gtf�D١��!ր#;�F�5��ul/��+		��5U�e�Y9w��aL��B�ݯ����@�
Ժϖ�A{oS9����'Vݫ���+T,Ǧ���$�{�~�C�����o��
�$K�9�������ˇ^.��A���@��xP|�����'6�]c��u|�/_?\�^�����j�]z�!Y��=P�27'j�8�ާֶ�T,�~��u�/H=��[6�]a�H�����jA󜣋
��hNTs�5���jyך;�b���� ���P����HgCe�����O�C�=C��	���P�Oj�$ݠ�IY���I	�Ĥ$"Tř���hH���OY��L�t-�y�aR%\�B۫���"Y�)si�NVw<�S�����Oa8㓜a@�of����=ٸ$������H����E-��;�~O9�������P�5�OX�q�a} ��FFP{�fUk2��6��蝶o�Q�Ko�R���C�X8�b�b<Ƶ�ܕf}ݪ-�a�8��c����F2�h�K��Gg*����7���D�_�Lػ`-�l���c��a���Yy���vZ�!U��s��1���'��P���#j4���[u	3��Y���M$��R�_*�po���ɋ�N���V<��=1%>�/�+�|pљp�_�&�Du�~A��Om��8�g�	��T��;A�o�B�EtB�Em�o}���6��Z�A���/'��ɪAY��Ɯ�En��/-�Z�΅)��i��~�e���]�UG/�	j�H�7O�Ӻ��]��?�g� 0o�:�Bn�-_�o�ݒ6� N2�fg��{�A�=��B`�D�Y���	��K�
�`�F!�/-M��G`!^���Ϭ�,Xw���f��n��e5��v�_>}���Ŗ��&c	�ó~�Pڼ�*�3�>����:�~��g�o��7|C#-�d�����ۇݾ�A��)���#�iuz����;q�q�p{�p�ѐ�%�tӵ4���
�t?�>s�I��Pv��4�g��IZpُnI*T#u �������>�]r"�A���)�A2�"���r��'������������ب='L��eL�bIn���o�G�L���E.S����'�|���|v8ч)��&��ҧ��d�G�3�X<�f2s��	_�t�^����o���}(/�&t�s�F�s~�9�\�\�9g{���3Pz �����^�s^��3����)�f��k���,+5��3�E3�͆VZaj&�g��.s2*7��Q�-�h\�^�ˇ���d�y
�LHA��VSS��H��⃚�A](�b�KI"���K�X�O�����ս~��\]��v��.�|�'���;�;<�ۂ�!�%"�����d�@�ڕ)y:L����V�9��0�ޒn_Z�y�@�4a��_~��F�W��L@��H�!!���+
��դ���F2���F����0��P`P�B��]��u�aʢ0ݷ|+淑}��ed-��9��zXL�`���7��}��s��1ݯQ��u���1���Ŋ:u��&���|��ZOg���h��y�L��.�?|h�����+��2�[�׭��`��l��KC�>Ԅ����O~LSx��w(��eZS퀢�sl�r1.���75�y���/�h��!ծt��V�=���E9t1m7�2�3�=�K+�
9�R��B?�V]s�I[��.�(�j�A�t���p���ͪ�K��Gd_5�w &L{�w{�cl_��-�A�!���d&��b�I��P�*�K[��AF��H@PS��:߭������AH�����B����ˇ�����)l��j�-�v<Z$-Ip�����/��
X�?�~;<��'z����d�>xgӓ�#�p�H�����go���_�y5�+�t���{�Q����������U�o��T1-��F�	}�k�df��=��~��{�e��n����MF�3<m�ɡ�L���U�;���]I��2�ơ��_*W>S�q
�(g�sR�n���B!�E�2g�^���'7����=�����s�,�oU:����ӓt���b��ޚ�+��fف�۾k�"}&�7z���i݊<ʃ����V�7����2*�cO<��n�aŞ�u_N��ƍ�x�M���}�5x�W���4+EH�ri�� M\��8�zW_]�;�w3I���j����>��à���h�$N�=<T�b(V���2H�����^�+��4���<=��U@ɞt3|GO������¸s�`�K�������c��%H����2sAW���2/ぴ�8���|�o�C:��F���e|!�}�O��S��
]d��7K/j�ў�@j(�8��g�[+�bEoԿ�A���'!�;�]�)��t�!|�bO�'�VE>q�f��g2-��L��orI	�)��{�,H5���v�0�$Z8�A������L����F�N����%��vx��P�f3-D^|P��i&�0���V�Ti&�>�b�a���e�4����V��o-��娗�?B�>l��wi,ҡ��{�;��<��2o�w���M����ᰋ����4�������ci�a�Ysp`���[�+�ˎ��K!�ƛ�
9B�co�,[&}a׻��*����A�:CQ2�/��Tdl�e�GԼ��V�9!�y�xT�]�~��$�8a��{�	9[��s�J���Q�t.%_�k~��{�qu�G�    � N.��u�&�uY�|����޸�9�j-l�CZ/�<F�&��x��(6�y�յoϝ�]�.L�>q�&�ksԒ�]�;/ΖB�MN?�@�n�e�����<D��L���J�,P�PԹ�R�U�A��	�i^�8�ݠ�F�9�F�>���7��A��~O���δY�C<�BV,�ǘ�@��%��f|7��!�_VXމ:����~l��a�w)ęò�gf7�u{����-6RR�2��L��	�'�L���=�^���-=}���rV=�|�Lg�q�՞�V�QK*��6 MK��HR$��ػG)D�@�����G�\��}(��+�[Hz*��~��ʫ���ì2[/��	�\{4�ԼP\&˿?4*��(�G�5���'����Ŝ��p��w�Q$=d��J�$��L�JY>�~�����Z���G
�bh|�m	�R-�uy�;PSB����rg�H�w�i���;�ć��1?w�Z<j��q�B��T�'C;R��S�sir�����Ǝ�!�J�EK����>l�W�'ʝ��C[�x�v�Y�n�~x�Z�lT$W���szj�F�r��{ ��~ ��r�g�������$��`�z_1	�?�G?3=�t]%IP�[`#('��z�A��4��2)�����W�կ�]�5�X�G�c<��}]�M2Tl��~��S` ]{�6���m:d@{�Ys���z�P:�ě��Gzt
�s�"���o�$w����?U�;��;9����ҀW54U�hx�XH*�=���.Bv�1�C��U���jy��B1���I�Q} ��y��%�^gG<ރ�C����@e��[�����֣oܱ���K�]tCz+W��3i@���!y�,��	��k�a����tH��A��S�7mw�QKS��8�i�Q�R�G���B��vu�������V�l��x�Q�٢����+��E��a�?,�}�g��m��4]3�p��^����'�����^�W�O��`�A�� `H��,n����m�=^T�� m\j}.�ᜅD��Y�U���݋+�*L넃��HY�y��:r;,\�t�l��p}d-���㹚,�����z/�G��	瘝�\���{i��f��tj�QhE��ܑ.o�3�WQ�otQ�֕?�>~%�I� /��G/[�c��u�̙����]1��ޯ�!��A�,Q�+=ѕ���q�M��Oa%���I�	�Ɂ`��oާ�p��=���QS�L�q>e��/ʚ�G�����@9��o�[m���%�ΗA��g'��M��,��3��Z����{�jj�����[�z�T��"��aTR�q7�q�9�y@��Z�*v�u4�S)��f0�=���e�������Tz��r/l|�K���y��&�k�7��~`L�����ۤ�kd��O���:�cmW�Q��I�����������X��%�ʾI�¯p�z�|�u?�L�&<O=J)�����,��L��JM1����;ՔЎ{c��)򭦎#����ZQ�6r���׃Ȥժ���S��QCOO,iU�}R4�*�V6����=0'�8�"�Tk�l�����������GQ�;�NCs E����޿UA��$�T�-}����4QB�o~�������/m��h�Q&R���}8��g�
s1R��~D)�9_�1��hw��I��-Zi�>��z-���pBr�O����[4O��dDDW�`{$tpx*�k����:�`N����"�r
��u���l���.�M�k9����� p.=�a��G=p�����u�r�O9��*��W;�s&pV{=�i茨e�s���)8�D�r=�k�>�z.+���F7�����"��SlImA ��͖��0h����L�c��
���}� 0k"�eŨ�ĦA��fa�ף�M�@�G��e$��)ˑw�p�0���S��,�Q��ɭ&&�0�3���l���l���� ALlS��a&�² kƂ�-�#��b�u�~{|����'��ص�&����T.�lZ�+�q!�PG�xLڶX+�8N�|�`N8	��#%���A�&G��s�Z�Sf>M3`D�����-���B�	���<W�5�qٰ�kT�4�\ik�8��D�����c��`���E0���GL,��O�y���ekhB���^2M3��4�Ec��l�PY��S�U�*f(�)�v[�J<Hb	��X�yk	f�4���t�Di�P~���5K��#��q�MT��Ī��hLC�e��][�E����T�8]��+c-�<|] ��^z(���Em���>��_n>�F�lg>DJ�$��T�$���6$���7��R�=�"D���MH�ke��Y���zj2/
�9O_:Z��<���v�%�o$�5� �h=!����l =���.G�L�9������y�����>�,��/��!�Y�х�>�J���%�H�n��� !%��ox�Bt֩R�A:|�`��o��)_�d�+�ڕ��՞W��k����~�џ�K�_6�stU����5�����<N���=E�D��--�X)^_�2E�J��W]y��ح�Y�����?�>7�$S=Y{�}st���٪U⏚mZ�Q�=6���&^�%�f��mI©�S�dax�s�k�\TU���a����
���)8�Ӫ�E�����"��{*5��yV'P	[��h�Q���*� ����2�#׺���\x�Y8��ת+0��أ1Y�o>��&�&�9�DE��NEƥ�͋�e�&5��e�&��谔�6�SG����	E�(}���y�ŻK�(�5�x�����09�;O��Ӭ�jw@䴓��;����|9G���f��Ψ��V���	y��d��k�"�AK�x𷰠d�Ҥu#x��UN�����S�1�FW�+�til9~x�1`�{X9=��k���[W��\r�	b����(ӭ��*������IV��CE2s�`�qh��\^j�>������,!oF��1`Z��J��1�LlU7Tc`��`�uR�r����$i����D�������e�-A]��ŝ��,^4,]��-��V�2ߛ׆��%������W_�::wn5�#���r>vY{��"���FH��l���p��#e�-8�
��ݩ�Detϯ��{rBj���8�ü8���;NH��d?$����}�J�d+"�Ψ�`ߘq��	�V�?*Wa��*W+�I�)�e5n�`�����5e�l(s%Bv~#�!�M��%J�/j�3�*�n�;Ŋ�Ƨ�i1K�97Kn�ū��,xYrהf�e�A�XBr��ڋ�����ɬ���+4KA���&s�ِ�i��KDn��0�!TbOY�lh��<��&$�$R�#i��su˱�`�K�ju�[�0�~uV�sa�B' �R֤�XVwbGMrBn��_�/�uv2�e�>:C���e�]h�?���q��]Nϛ�v����5,X�޶>���C*��цO[_=�W���t��s2XV�l6���D���'j������AlyUBo�+�}�s�T���f�>�/�L�h$�(���������@�|d�n�J�B��� ��/�z�=�YQ41�|����0����`Y����⣹~tfALx�L�Ǡ�c�bִ��#�����˂. Z�8{v�X �v����m�ұ�n!zy�M�p��%-�l��i�ܴ��*���"m�˧BCgش+�ŏ��C����b���o9SQK�]_X�n�� ���Wwuk2*�i�u�칩(j�ׯ�Oc3���
�"��V7b�L7)�@1���r0�]A�WOM;xە��x<�5��/�"/a$����-]�����
ù^�y����G�T+^.:̼��Y.Z����!{�59��YZ=k񍕋*��h�1P���[�����2Y��9P�ͤʴ�d�8��T�*�y$��S���y�� ���ExP�"s�E�3���\v�Yo�۵v�E�o�̛LRV{	�is��`²���ȅ�,n�5��SQ��m�`~��+5���M^����=/�ȸW�4�����-���h ���j�!�6�"    ͕�x:�/�H�zi(Y�LH�E��y�~Q28N���K�5��Q�k���
V>�Z�0��`����M���z���v6>�e�Y	f���lv�6��L�0�C����8P�֑p|s��=P�ML�����113>q"���-��X-�5�ز|�Kx������ke�a�^9�(�RS�@��eb��P�~��H;@�5�,�����1+W��4����s'Ҙ�������a�ȤO-���Q ���ki��$��5�+��۴eD,��0`��7։�u��	^]_ӶR�W�{C�����JG+H����7$і�<=���k YHtM���Q�P�����5Y@�G�iJ�u���)�|�Y|r���Q3�d;�g-]�]�ąQ�.p���p���0��<tp؎����q�&�t<�E��3���b\K\l��� .�'��򽙾��ғv�f����I�$Q�6e�{�zܜ�.�<�<�N�����E�ލ���\�W��Z6�Rc�v��3<Y3�-	���r�h�3�Bq	�vm�r�c���,�|z!;i�������x�*YT<�G��sk����k�פ�Q_�N4�~�@����Vg}�s�Iţ�\�e��N�-�@L�x��32���ݡ��~{�beb��ղ�.��[���Ba5�6��p#�kͦ�֭��]�[t�����i��Ő�<P�j�m��\�j��<`zv""3�;�(���蟾�- G�#�������T�T�����۱R1E���v���%N��*�n�۸4���{߶Gp�Ѥ$G�ȥ�b$d6�oz��>�kk�8 �?ʥ��0�D� 8�~>R��>�N��FRV�4��y2�|�����aE�xcuq�В���]ƺ{�ݖ+�϶ψ5���3*�z��m��n��f���#���ۑC��Q"����/+�`T$��.����Fru)��@�k�R!U�6���y��GE^�U���V�X���3m��6�pϴ�'^���\�Hl�Y����
��ޝ̳P㝦���ɶA]CY2ჭq����je3�48��0��pq7��9�e�a.�&�/]�����i3��a�����?e[��N__���1Jko�7��j���cXr1Y!C/?� ��L��]ml��p�ծc��UNx[u�;�Sp^۵z�i~+��CLl����O_��v4��w� �.�T�M֞fs��5��h��fK�ޔZ�^iF��}��!)�ǁ���ή=�g>d� 2���\�LUC�Y�b���,��_���"n[]�X�_�S3�qՅq���-�<vY��vr
�X^c����n˵��8Q���F�gm��F���ޘl�+t9�4�7ǭ�i�rB�˦��a�C2WhC8:�YG�Ei��w��BÒ6ߥ��E˩.hmlxR�=�E���͎U��[�0c̱���}��2+�,+Z��;�����;������X�H:nѢ�Z�`����4��;����-�h�V ���G���H9`$K��h����4�o�6^���-·3/ cԈL�&G'�b(�\��*�p�	u?��H�,�zs�r�@Z��K##f��R�0Hw�S��R�����v�=�u��������`��dl�m��e4�U���-��ygj+��6�!���n�/�����t�� DŠt{lBU���tᕚ�d�u]�)=�fD�v˸�8*��Ci� JV�w�y�Y^0�0d*��H'��zb�� N��U��'־kj	Qf)�$����Z���r8�dm��½�u��ݷ�����s�܆���<2]���lqe3��n��8��z~߹��Y��c�DCǤ�X�1+8�2E�L�~��sT�"����Iփ����H1�]�	�T
����qL);//�/g��Ԕ\��V��Z���yx"�9,�O���)L`5�k�Ⱥ��WWΣ(�ѹ}3A���jJ�dy��r��k"%#�� ��}}�bH��qU�0�</51C��<}��M>��5S�W�
3�h~�����=���ƣ�O��7.Ѱ��
��i��G2B����C5�s�z�,�g%�w�0�	Jk��"'������T6����F،��$���>x�c9&f-:/|��!�󥂅<&�ﰐG��!��͗��<o��@�<�QN�yj���U$�� gR]�����7��gfL��d���J�<�Cd?��]���=�Ȟ�Y����S��^�y&⼴�S���{1�Ü��0��6��$&Z��Q��%}�L���r�{f�s
���������r���|G�1��d�n"Α�It����Љ�Ug�G��I�_������]h��Ɲ��,i�͊g2�{�"��3'7��(O�Ct0��R��0��R����b�������,�Y�&_������ڵ���g�Iӫ��`2�<-=O��A�<ĭ| H�Rg c&���K�.k��%��*]�̩�����-7�z��Ԫ�K���������_/?���Ft�wV缩} �4�̌�E�O��ľo����@�#���þ=2����s+���ї3W��� �Ӹw�"�0�O�4��׼��]J�
Ov�0l�%m�ZC\�h%K����i�#��@,�z�b�N�aؙ����w�~yT�g�Iv�qYG+ /}�4����w�K}�<ܕ�cMFb#��P/���G�%�O�J-˩����+�hD�N��5��������y�LA;�m�;�0p���զ%����a=�2T<����/<d�	X�Y,[@��(�X���[r��Ql#��Q�N��j����g�ԧ�.}�=r�K8Kj/�L�Ȫ�@�_g]b�D�[������[��si��|��*8Q������M�[�������085p?tJC�re��7	�������g��Vmv��Wpr�<.�hW�`��k����:�Y�7�
��&Yz���c&h�ȑ��{]Iv�y����`���%x�8Cܩp���o�]������j�7Nͮ@#p4���'�qF��^a}\0���vSX0$j/���wV�sqd�=H�>y�$��#ah��Y���/
N^	�\�H�섾t�#��%+���D�T�{G&`����h���$F ʳ�c���E�Y<vs�	��j8�*26��y�K�Ҡ}���H�!���D5�?����)i��U��c5��t��X]b5��?�1@���R�^���;�_�d����]��eq�v� �����Sl�ق�;/�`z*�{Ρ(���9�������K��ʑ�p��J���u�����ǔ-�~l}��U�z%V��������=փ�A�b�x�������6XWs�{m4�Q�R��C��$��۹\��0��$hX}��`���j���=>� ܛs�� �Ze�j�ޜ���Թ=A�D�
ԺYw�t�I~;�L��Ui��G�s��q,�!m���h���]X.)�]�A�<v�w��tK��rcj�XƬ�hi�J:3��K:@f����ݽ�}Z�7T#��ͪc���/l��&^��?����X�%5��z�pXM'ce�1�����휉�l�ˠ~c���3�1�N�7���:]%����e>yr���j	�Y�B����A�C�[n�e\�Yr�U��Adv��o�,Nڴag�o��-2�#` 

��FK{��J(�v�H��w��b,	��(�fk�P����TL��)sGT���ƒձA��:;�dO����-�,m3&�Fs��K�ɖ�a��i�ܰ��2-��4�u��rj�����bSu�q$Z$C��BR��2�����6O�\3K)b:��:��3)`�V�@+"ݏ���t�*� �V1R�OAôA�n�*�Y|���&K��	Ѽ�]ޟ��7�o2�8(&��
���bK,�w�h%���kp#	r���v;�����"����LU�]�}��B(7���n�	����&�ݱ��zKr�?Χ'wkhT�'}7�>���=}k> ��-��Ⱥ@]��������h�R�����[=Q,�&��d��sk��Ð
A&n��HS�K���a��H�d)#^�|�	2�5�j���>�V �  #���HZ�^�E�7|�z��d�(��T��"-��!Z��&��r���m�U���x �,{����}����2Z��2
V�s?�3�xVf���"}�9Cb���\�7{��;�����vX8�"!7a�l��Gҏ�u��o�s��vP��I���?�1GZ&gy�UAy�+�Jq��c��9у�K����KLK,R��]�3�-$��ٷFr�mq�,����\��.�5p��בǷ��Y'W���zh�x�1n�R��}"���CT��Z*1��Zj��rU޷�$��~�E�4�lH����ZS.��b� �N�4���1�RDś5��~��26��)U�K]:�s2�g������%���b���4�7dj�yC�y'����xl�.��#�R�5ސ�{�=�yXvR�C�B��r3�����?��͝      �   E  x�͓=k�0���
mN�w���ԩC�@I�I�{��!��Wr[�ܭ��ׯz�{����e#��ͳ8��V�ݶ�W1�6��v�5�}]����C�V��?o�[ߤ+��Wsj�Ѻ�U��۪+ž���ǧ��ZL��.���ĳ�� *�f��=�MZ��\� ��$ZP�����d9�����3�)r����`HzR&�L#8�`��\����XҒW�E׌9��" ���:�v$�a8�Xk��� #`�b�,�7D*��_�;�'A,�0�T�N�~�P�E�{�1ρV��c����jV��q$�L> I�v�      t   s   x���v
Q���Wȭ�M-��M�I+�K.��ϋ/�,H-V��L�Q�K�M�Ts�	uV�0�QP.�/P(�O)+V״��$�4�iA���E
y��)�)�e
4�@fpq 7�FP      x     x���AK�0���O�`�z���
s��<	%���iL3�ߢ=("<�O���R� �c^ �����{I���f�t��B�բ�լ��*ne�r�i��㿗�,���*��B��H=T'���y���n��8��$M.��'+t�#z��Aϴ�~���O��\��]�B��eN��%�����6Z��X�R(�g�k�
Fh&�)�*a�L*+S\��Ql+�Vß�~����S����&����;i��\x'��IA�Ȕ{�      r   !  x�ՒAk�0��~�wK�$�v�N;x�AkWz�P�!��i���ﾧ�c�]��y�������&Zg��#��Zun-�c��4��YYPвV
��|HM�t^H��Ce:u�J��Yi��KnύoZ���z�˦V�í5�����m���@��t�$�
ƃ���c�>�dR�\��l�c[d��B�*i�GQ�>}��?&�{'�{L�e�3��δ/ �'��t�
�� �|2Y�e����\N�O�y�ܿ�l����Ã�_��}�	c�
�(>�XM�p�w%���      u   �   x���v
Q���Wȭ�M-��M�I+�K.���+�/Q�HI-N.�, �u�$�3Str�ҁM�0G�P�`u7wBuC#Mk.O�Y��Đ����F4��
 V�$6���J�󋲁v����4IT�  ���\\ L#?      �   �   x���v
Q���Wȭ�M-���+�/�I̋�,I�-V�@�St�R��K��S���M�0G�P�`Cc#SMk.O�id	���5����h&�<S����u��	���u��Нf�5�G&�T�#�;ML�frq gMՒ         �   x�ŐMj�0��>�씀c,�Qbu�E�B�5�ڀ�K��һW.V�.��Bz|#f�S��'�����A��޵C�z��N�WS�N����y��^Ԉ*7�����y�ԫ����u��py�χ#�h
��E�eN��6T@^�m.�]�w�S���q����4^�槿>��!��+��R�a
9����0Xx�)�s]�-��K��C������UH.$��^Q����$$�{�i��/L�i      �   �   x���v
Q���Wȭ�M-���+�/�I�+�/QЀq�3St�t:���Z�\�YP����������a��`���n��5��<�i�mm0B��M7�����"uScӴ�4���-�k�1Ă��ĔD�mD;��Q��� m	%      �   �  x��_o�����)&OkB1�r�m
�uZ��Fr�>2Z�^X�5v)7ɧ�]/c��Ȍz��� �#K2��̝�g�=����ŷ�����kw��M���fۮ߮��v��������m��̵���~�?�m�;s�����ھ���}f������5?��������;�W�����Wo^\��E�����W�������vu��f�.~����ݭ}��~�}������͇�}��W7���>ֻv��wO^�%T��d�ͧf��O}!8|x?���_,�G�_~��������u�u9���/��n��>����'�L�q�ß����>=#/�>y8(ՃA)����`Y&ΰ�+��բ���>�����YH�c������O��T(Q�-#��Ĭ6�Bc.e��#�+��g�˴���0%t���B���/�L�B~��Bs���c2d��Y+��&C����ی
/�0NF<t.s�@QL�P��(f�P�
"#E�YX�Y�l�aX�t"3�$�"�޹0�RD|]h`�49y��,/��f�9Ȱ<��a�Rf9�y�@!L��(l�,�0�~���fa�}�Y�F��-4B����P,KD���%cT(y�c(Bt�y��P���'2��T��'T�~U(�W�k>լdl��ƽ`5��c�A�%��Ӽ@y(�P̯D1��@1�2���Ker��/�8Yy�KC��d"� X��/��4BUXa�I6��|�����*�}� #X��VF
�,�o.`���"YቪdU�:�X����E0SAn�����2�X�.ϽR,B2?��v�����mno�ov{�}���M��{����5+W��b��ۗ����ݷ�~Pg?C[�7���K������oc����F�n�� f>���۞�ﶻ��n��ܦiV��[�}�Y=��{���/�%%_�`7�)�((�FQ��z����B�eI�TI=�P��P�S��T�P�T�uIXhHL�J�%�<���@�a�:���w���ظљ�J(��B�����`$���T��M�Z�� �⡢p�s�$�
u���4����D5ƒg��,,n_J�y�h�C0_Ʉ�j�JJd.ꡈ?Q������j$G��~e8`��S��_�xf��7�2f�����A�i��L��Ѯ�t_�JJ�@�21�ʑ5�/�^���}�<�4���i�T�0�	��Bf(��S�,����X����`�P���P�a	K+�&1�KZ���A�^�� �,�\0	J-O�[�[v04N&��Y<)��6*�T$���"��6㠁��k����~s}�g{�'�����7��"�P}q,�c��3�
郧�i�)Sۄ�?P�>�4E��F�O_2�t��/y�B�I�*��*O�e�}�g*�<���ua�s��n&"�p��@)}�:�����R�5���	�B������T��L��!aM��i81v+Y��Jɓ>�/U`�/�'J5������ԯ���$�'�$�T�f�1�<�ѫ<�q
,�aBѼǶ�0��y/4N�����S�M�
�����OÐX?6J��72j�D���U���B�y��=FT�Ѽ�r(X�,LՋ��&���E������*S�`�Q����`�<�KC�D��P�PSx�&� e0��(P�hH�Y�"e&K-�׍�� VL
F����0%h�����@e2���Q����(��3��,AG@�y�2c�"���UE/��94Uo��׫��Z��޺?ԛC��vmz��ac��n�z�כ�����ԇ�l�;����}�m����~�ա���ϝ�럚�kow�4��c�)��o.����q�d����{W-IP%�ͫ@4�m,P��&�C�^��Dc��ݙD��ǐ��O�d(P�
{�$������P�`_�i�ֶ&��4Tk����F���E��� X5��3	��_��~�$�e0Pe�b��2��>�no,�L�(P�<3�Bc0y�-��?L��XHƄ��T�0I�k�h�4��`L���P,�.mlG��}��
O��׸>j�L�K���fa9�4/ �cDU%�+��Sg*�D�7�1f/JT7(IV���`�8<�KC��P0�i��e�J`
O����t04���B���X���yX,�Ǟ�`ҝ����(S��v(�˴4cb�T�J���}=� �����T��^�}v�[�������[�Ç'�(@�ο�K��[�� ��V/.?�]׸�8�U٧O��7����u!����G$�*�D刔e�nO$��4(��Lc�!a�]D&������4��`/*E�ӄ2R�`�\D��2C��
��Zd`�u�Tq��Xle0�b�AY[�W*2M��/ynN�`YE��c,�]CŤ�c0�,.U�4t�@����)2�K���f�1,��a<�`�KŤ�e+�W����"͛�3~aR�Vl
G�Խ���K�8�t9�b0X{!J^#���(SAY�W�Yhl?��<��AT�Ӽ@y(P�B�*d�G�q"�o0���`H��h�V)c,���<,��A�Rq�/b��$Yj�|엉��2L���/X(��c`l����LIY�ҟg�n. E7]��}��n��w�ի�۶����f��f���bB���#Ѽ��`O/3��� ���4�Tt�T�	{� �N%l@�
E��a�$P�L��=^�sl]0�J&������H5���k��5���v�h�Q�`YE�da,��#����`eM�&�<ńY�`ar*��%�YN�����$1b+�$&uT,RfBѼ��1{&�W�k_�fa�}�e�R�,KNT2ϚW��^�Ǟ��B�k�3~e*(k^��4�A�WP�b&*�i^�<�qo�
Y�
b
O��t0$�}	���c^�a��:�����t���2����q�4�,��Ğ�`��+.��jq2e��K����b/�]��n������ξ�l�=�&�X����BqP �M��u$��1�q[�!��z��R6�@���G������(��k�@�ܒj�6am�jZ(aW�%մP�ZM'��2&�ت05�
�P�4��*&�Y����,,F���bj���	�
�WT���d�J�1�P�f��}�^�e9�B&����b¤רy��,,�X.��pʘ�!�^��.�W�����z�P�6ǌ_�
ʚײ=�Bs��U�F�����[���c*(G_BALቢ��������l�q1�M�V����ؤ�R�s2�K��m&X�\1�kb' ��*�i*P2e��2�_m�����f�v4?(/ev֑�b���g�!dt���׫��β�d`u�>|���e�C��i�>y���꓇2�@4��<�Q�`�ڑh��X��92�p�������;�O�0��|�)�� �9��G4���3*���Jk"a�3D�����K&���P<\RI4T
���a��u�E��ӄu��L��f3�aV�g$�:�P�C�ո�x�c�N��PS2)�)�.e�^x,���$�%/��f��~,����G�-+*�o���D�ǜw,O����7��`�eb�cV�]y*L��J�X�z�L_���4oll���Ӽ�����K0Ş��B��e�
��7n1f/�t9�y�V�,4��WT��$��P�اT�~͋�g�.ї��/<�㏾�Cb�F��3�KL�H�na�*���S�P�+%;͠m68 h,����d�����43P,�)��Ų?�.>��j����m���4����T��7����r��Es|��՚oY,>t�-����}��b?H�      �   F  x����n�0E���ّH�����B���6K�� Y5ƵM��}mG���7��#K]f&�Ң�lW�;u���С��W擎A*l�o����Ib�Z1iX/b`�ޓ�[z�9!$�h�D�l���k'�Ud�2�BP-d�q���v�{����}�OV��;��6 7}u,���P���tt��d�����kԞ�O�<�;�YS���̜*�-���W�|����W��PR�|�����>�N�Jr:�<5Bn������K������p�Ro��<��:p�vK9��~�7P��M�ỷ����4*F��ثOث������k���      [     x��mo�H���SX�����G�^�9T��@.�W�������� ��@���[BDX�_f�?���V������ǻx�f��f4�y��]\����y2H�k��>�k�l�p�<ޛ�g���|4�Լ�M2�jV�ӛ���<����7���~8H��� �y��/�s�����޹l��7�j^�;]L��Ћ���j�C����7��?z���?f�j7e��y������/;�����]%���zFLD���)^]���/��E���!��|��$��]�����E�YQ�]w����ǵǸ�{S�����r�ɗ�6��Ly��
���ߏ� 1�M�����U�J�<׶����\ٙ�Kdv�O��/q<^�	֒x������c/��b�"^d�7�M����B�g�S���h�����0����{�]1�|�\o�+�r#��F>i�}�#�T��#��ŕ62O��������/m�w<�l0g��<��ɖg�{�z������5��`��O������)80��s�]�0d���
*AF��~��v.��f�[#�7�[��D�\��z���[��e�Rs˕��4��y�T��7��YɟG��6�o4Ϲ�>?��������7�-�V>P���Sޭ�M1�)6LQYK��u%�+�V�9(���gC�qo?'V�%�r��|��9�Җ���_��Q'�d^��c���ʸ5in2O��t�\�^)׈>�i�	w�-��X�S�hѩl3�.������2�Tzs3k�/p�� ��Q�i���m&h��u�<hS�ޒ���£�ΎBg���>��Hn�K{���J��)� \wri3��F����ogW�L�=�w�J��$O��ͦ3�6A�j6*��%5��3D�Xo��S�]���t�yBe�-�n�&��f�6!�Pé�r��3�V�/~�T�z׵_^�٘�r��X�X��1��/�T�:g�z�}Av�B���]�֙�	'��:qE�Ժ1&��L��J�*�RwF�I<3;��d����2[V�o���w�9�-�hO���(�]�G�?�{�����Sd��uw�<z��b������6��ݨi��b�SNH�ʹʞ[�lc���v��̬��}��G��4"�r9�����"�1H	�da��4���a�-(���P���k��Ծh�턅�A�7��)��[����[�E `D2�ƅ
n���e�NB����RT��
�����d�r��?�J��C�!�b�T$0M
���Uvz�I�#a�@��}�T�T, �QW���>�K�N���E"�Ѐ�eN/�M���k���5;7��K��@EV�����@��/�6Xq3s�F4������_��l���{G��]��'遊8� BT�m��4E&	���%'�m'µ=�h�!�!�0,,�f��}"���0Ë��_l	���F@^��}y�fM��e�C����I�.�&�0%�܄�������ژfd&��c&�d��e����y�������]^SXb MY5A1>�{%�~Zajh��"d��ի8��$      ^   �   x���v
Q���Wȭ�M-�+H,*�/.I,)-V��L�Q�K�M�Q(�/�/�, �JӋu�K2�R5�}B]�4�u���K���@�A@�_��PoQi��5�'�l5ڃ�F��ҢL�T�Zu��k4�8%�8��`	Z�j4��������:@�"��� �k��      _   �   x���v
Q���Wȭ�M-�+H,*�/.I,)-�/Q�@�f��(�$楃)���E�%��y�
a�>���
�:
F:
���\��p}��E�g^���i��I]k��̻>�������ͼ��YAˀ�R(�O)MI��c�~�%
�@;�Ric�!��0�����_A�6���xCH�4�M v�&��� *2�      \   �  x��[mo�F��_1��	Z��]��pI˄E� %��� K��D�|���+�\�4h�h�������rwem��f�EA�g����<3;��y��!�GpquQlڗ�u��
��?��W��.�ԗy����˪\-���?�D9<��W }�M��/���I��BZ��L��٢��j^ GA]�<�ڞV���i�,W,$nYA���M�%|s�xUV��0�aZU��d[�b�}̢�m��-i���vE�M^�UH���"�=�1{.�=�P���Y����(�8����f)ʯ�5*��������P�XW_��q�yW/y���������)L᰸B�UL���]��棾�?���*�%��s�8Ӑ�b���XB��e1��hn�{�)����$�������$��{�	�se�F�~��ҿ�I�F����y#?4O�^|}��|��7/�gX>.̒��|#YA:�&q=H�h��G~R[�A��~��0U��ʻ�O>I��g������7����x�������[n�x�N>���_8�9z#�ϧMF�֚��Z#�	'8X�9��m$ǅ�3S=0g�\3+�����t5InS^\.pb�0��qc��_˳�r���m�ͦ]n+�dAh���B:
�c��&�,�mF�(Fc�,D�X�t�dO���s"W��ps�~��Q��8�`��p9.7�f�*O7��x�9�� �lm=����I�ՙ��g�H0|�wU�t�ۦ�0_P�A�ˎ�X�wj.x�V/Y�FE+7,�
�f
�c�l��i�*�A�Jm�j�֒�t�@*Xn" �4$�ܐ��N+8�.���\�*�r���h�6MQ.����ݖ��o�/���m�T]�[�������!pi��4������i�m��*1���77��������ӳs����Di~�?��F؟��c<ɡ7�%d�Q��=��3P�	��ܥ�|7i��c��4��
���.	�0y5O��˃�5�l�M�s�n6����Jq�?�3G��`4�Xd�ګ��OF�d�g6]�x�h8�F�A�}�b{��3�Ͻk��b5��לT@�	h	�Ƌw3�.8
!���$��P;Yg+���B?I�&\�q>e&�傱#He�G4I�4m7ҏ������
��o8��$�݆�x����t�&��Ǿ?����:�f9���'�X���1�k��MZ�ӪM��l��a�4"�6-�ď����DГ,He�0�d>G�f���NSͤ�c���|�(@
��_�&g���
,,�%� �����P���������m�1H��4�ߦ�)��N;�e��Cd;٪�Ѳ�X󙦪�s?�@����z��̛�nc�{˞�a��I�n	ΎZb��u�WJ�\�s3�����i�F�C������6�F�i4�C��ӈ��X8-�1���m���P��
�L���e},k�(����_w�k#{4�D��!�Ɩ��8u��t�P��!��{�&K�<��t���4�F�$�b�?�kc�ߏ�	Rfqh�C�4\S�$�d�
�a(��Q_st��4�%�KS��4��K#.]#�{Y������i��K\��IO���H��F�&���rs^̡�Z��t��i8CUl�P���^��Χ'm�T=����b.�r�5���X��i�=]R� �.M�ui­���jz���2����� ӽZ��t��1=1�1�<-�&8;4]�MۨC��;4:�c�]-��Ľ^�I$��4�ZL���&��h�˳�Xx�l�d��n��,��vy�,�����E����� ����qw�z�$�i~>=�Ξ�y<+��h����Ш���ٔ����a��'M��4i��F�x4�����n$�3sPx ��%�Ar|H�i���)R&Mz��꬜�f{y��%�ֶG#�<��G쭧_�Z�r�Zppu�.�JoIb�4�G�4ҭK#ݺ4ҪK#��wM����Y�t���F�C9��������¦G�����2��g����"5�49�K�a���"��LuI&�8#�)(X
���i�u�<��
�m�4h#�����|4g���F�k�\�qfѼ���I��d4�2��|I�S�D�m��x1�,G�<%Q��I�e$דt}$�J�c�13��C�Š9V�C�(Ş�h=�H*RK�Z���`��UW�j�q�Z��
���(������/��:�Ǎ]m��5�J�]�ek�5��"5���)����<�#kK�      S   
   x���          �   �   x���v
Q���Wȭ�M-�+�/�,���+V��L�Q�K�M�Q(L�Q�(�Q(IL/�Q(�/�/�, ��&�%��i*�9���+h�(���&g��P�P�)*�����p;��i�9ũ��\�Tv�!�_���G�&�&�{ԫK�2k������ OqX�      �   �   x���v
Q���Wȭ�M-�+�/�,���+�/QЀq�3Str������������B��O�k���������zqbJbbq
�T״���F@�O�>����3�k���)�i@�Bu��hh�!��6��M��4���DuӍij�!��\\ k�      �   �   x����n�0��<�� ɐ�J=��V��Bh�-X+�Fk'J޾v�GȞV�����MW�z�M�B_5�ra���䐩Q�HM#����5g9�(����g�!�
����۩?О蘆ɦp'3ʫ���6v�i�?'�=Rb�{���L�C:�/�14Dγ2?�,Ç�2���Z��8�ed#�V�K�r��nw>��2�{�ǖG�W9�`cw�X��8��7����Ec!�A�M.��:�$�!͐�      �   {  x�ŜMk]G���w���i�骋,ƅ&�6�����Im�����WG�vQ�k���l�����+���7�x{��y���������������Ç�I��zz�������?=�O�}��������������������?�_�}�������߽~szi�|������������������o_\��-�C��x|9�z�z�Awa��k  |�a���?܃r��5��zxl��-`���ԙ������9�}hCߒaߋN1X2��qR~0�&�Pr�X9(�z��d���0tF�é$!�4ʑѕ6Q3!
x2Vnx2��`(������D̡(N%��⦌K!t*�`��4�y0�3ʕ�s��T�Nj��tR3/Wd
!�ٔ�A��� �9�T3gBL0j͕�K��\/��wY2t�C,O��y�U�a��P�a��sx攙�����*-S�A�*�F���p��[9�x�d�����r�\Z�m۱��r�H�)f�ڃ�0.�wy*A(|Q	��*[g��8 L��X�`f�R�B%�FA����a�Y�A�{ ��y	:
S~��e�Q��Q �"ڄ�G��W�֤ /�^{�G�+���r�Ɋ�7? d�v(�i)�R53W�� o��)2`����m �y@O�	�(�>=+ɨa*������V���GT����#��i�d c�� &wk&YR^�@�il�,c�}
�yR���m%w�m�G�<���R �*��\	�Y�6�ڶ]��3a�ʕ �;3K�&j�����Jj`áY:+���bj�e!�a1��aO�f�� �iLڏw�fej�J��r��2��^d����kD�L)�T/��ඣ'D� �]fB���B5D��s�5,F�r���œ"RH�5i�>`�)��'|LKO�J'��� %s+3)tL��X�!�6
�>�0V-!60��P�(�z����R�}�����}ц9���u%Z#�5���6͒M�$�+��^pa��+.L���/[Q�Ua_�a�(�|Ն�����m ��/�K���I��H5�R+�zr
͔:��f�E��p�Q�d�gT�&���@`���H�^z�����������q�LMێ(��:��Ac�>{�&>k�W���� ;�j�{֔E�#:=�3!���R�[�!ZB��j�	�}K:5���������YZa��]Mn�r��-�;l%4����v;�3�R7љ������u���(:�-�#�w���ڃX
�IHnp넫\�.�47��s)@�%����o.0��4���dS]w�6�>H���&,����6��@�I�])�k)�bF!ѩ-��{�����l�V! �����܎���?\�Q�      �     x���Qo�0���~�3ٱ����X��R�0���)����i�}��+]ߖ{��E�����ً�I��XnV��r���SUnm]��˿לU�G�r����w���Oq�o�����iv�6X�gg��}&B9��L�rճ����������nV��i���Xy�l����_�VB�f����RH�P AĖ��f`K$�ݰC$��m}i�la�eKGs��r�]���	:�l�FXғ�cE�c�'H�g�7S@�_c��
�	�#�q[�Gp��v;��Q.�N]�q׾2|�Cw��?�|�`���+W��@�
	�۰5D��y�VD���tC��"���i3M#�i��~�Nh9�<��Lpg�oӇ40���O�1|���[�E	"�Tq��Ð�b$:��k��jόff�&G�f0��CȦr^;��۴�(��p���H�.ڕO������X`Ei���"yu�#+<W{~,+�������j��Ou2��,��Gc2��U?L��_����5������E�      �   �  x���]O�0���+|G�6Sb�ݮʤj�H��	�M7Z�t���s�M�qQ|�����s�{lf�Ev�d���=�z�͇�z�h��ہ��X�V�汮��~7a?vk�����o���	����/��b����`FB�82w�"Z���]���@3������:��x���?�S頋b|U�ۺ%�l9��ߌ�;{���J��v�$f#���`�(K[���a��e�����.m��-�F���ݲ	xY*]]6RWگKJו�겑�d�.��`]�PW��ԥti���K�겑�ر���v��b�t��7�)h�lB:I��c#S��۷����D���i��Q'�,K�=]6rj��������ˌ�4�2�$$��&8�s�c#;��	��E8yl��)#`����S�e�j@8]q�Q�LnZr�.����+�J��H�ӕ�Fv@�t垇ƀuN@Y
������)s��2B]]6R���垊|
�E��=6RW������C�i�1�`Y���0H��A4�������H�g@�x@.T���H�\豑g�m@+�ժ)W`#�d��S2�;۬��8a��"�X_a�-��E<E�	���~��h����u,��N�z���I��B+t�z������F	s���R��R�)�ZW^xldw��K������r-ܺ|{��}��[dy��K�?�c2��      |   z   x���v
Q���Wȭ�M-�+J-H�,�/�,H-V��L�Q�K�M�Ts�	uV�0�QPOM�ΩT()JM,�M�+Q״��$�$#�I��y%�e4�%1�r�L@��d�*@��� ��^�      }   �   x���MK�@�{~śSZB7�<	m!�)�h����`w7lFk��� A��)�a�2���C��(w0����S��Wҷ�U�Ť��Nq���+��;zn��]����q��b�"K�-�w���j�b�+Jl��!9q'˛(�\]W��[� ��l)*�2,r��^��3�멇x�b�
M65���L�f6��۬5� �����b�S^� �/6��K(2��T�Q�	�Cʯ      z   �  x�Օ�n�0���禢��?@��.r)�P�L��P1Sv�EUߡ0i����uv0�V)��%��'#�|���v���b��ŹPڭ�1�+�yJ����6Ievibp�i7K�I�&P$��t�3yy�5�Tqܗg��}�Μ���$�pKU���|����o��#�l�6��29e|J}`4�"�rX9ՙƑ� C��pr����p����XX�kM)el �7,�\?ՏP��_���O�M{lA>�U�Cݙ��t5Z~��3�q�Sʦ4�"!#��e�-�;�WJk�T�Y���#���E8�c������x\��y��,[�L>)h��/x��Vl��MZ��1m��}R�s�=�
\�8��ri�|1%0���C�YD��ـD�t}ao����l�s�?�Su����oe�{�@����X2Ŭ/s��S\&�d�W�      �   B  x����n�@E{Ŗ Y�}�YD���RD�@h�.(����}江p�;��=wg��q�}r�����q^�q���6^�����2>_��кyz�*��Kw�����"�֥�:����AȜ���ȸQdB";E�q��Y�V��X�hǓ�H�rDR2��(&w���D�.�`�Q�K����(ݕY��]�T��8�ɒ�a�3�,����IƄ9�g��yfJ��)jg���� ���!X��i9
�u�;��Q9R��`9�Y�:OX���$LT���!w�^��:y�d�(�r$���A���w]��}$�r��d�z�K�M���=�      d     x�՗]o�0���+|G+�McB����S�,ݚ���&�D 3NXT�����L[�K7�������I�4%����,�KQV���j&�\U�UMn�H!6� �m2Yd���z��T���H���!9����R`�L����I�v�g:�qu��<{-�Z��&���܍��	�@| 1�=dS������|a��x�����ک�y7���Ѩ;�~���`���Öl�mJ�e�JY��YQ���G��Z���,���R�o�<�^��1�Q�` (+g{LB�jk%�i�1�#&C�����5v���8[v�O /z���-�I7��ѫ�������[���B�-�f�7Y��jH'{�B�+��-����b��������(�pN����aZk	Y;F4i �.�Qr?�$�a�����=9#���FZ�>���;yh��1�[��e۾�5hj��$��Iɺ~�[�z�DX�/��g[`����DPY7�>UsYAǫ�'�7j�T^������H��w��      T   �  x��X�J�@��+�����MM� Rz�Hm�ZJݦi"����A������nj,H��lK��fޛ����c���9,�\H��\��$�i~�&���&�ځx�D�k�fR�d"M�Sm�:.#h�.q�:����Gr��h:^A����/.���q��n���`}�!Sk��21l#��zv���h��h!��s�ʭ��)"�8,�֔w�)�Z�3�����T&"�@��<Y+�:i���3<��b����?p�E �&��L}ayImxIP��p�J;�P�gF⍣�k�Q��b�K�T�(w^ Ø��W���
�W��i�X��t���>�	Z�iڙ�5loh�Uu +4�/��K2�M��:�M�y.��r���71v6�-�`R[-3b�Щ�޶)n�� �q�P�E%��]ðZf@��
,xjޫ0��|��[�橚���j��E���UW�^]�j�K��/%o
�M�Y�M���c<�z?�v��i4>TvJ      �   9  x�ՒOk�0��~��
5�jv��� nL�e��-�l�:��/��첛���{�$��f�\�^�`�\?��XY����}ؼ-+�l�`T�l]S�F�6ms��(O��.�&{�lݞJ�ϝ������k�����<X�ƒ5��q^��
�)H��	�� �b�	�KzɈ$�$H8��a��b�o�(&8�1X�3aB�=2Nb�u?��C��hg�KE	d���"3P���lkS����&^����n3�7�+,"?����B�o����Yߒ (S�*�A�ŭ�
�Oɟ����:���(�3�      a   
   x���          �   
   x���          �   |  x�͝ˊ\7��~�^�0]J7����q ��5gBl'����ԯRe^��E�t1|��R�ϫ7o_�����ͻ/���|��������On?>^����_o.��ps9�������Ǜ�/��n�|���������濼��N��Ǐ�x8��������/�^��Po.%�\Z��H<�����ow������/���:�Q�d��@Kr�HǗNŘ��%c,eg&�t�V@�O8 c&�ⱸ�RL�fR�cLvdb���]Y���2F݅��N$�ʘ�q�26]���D	����*G����M�z��b<>B��b���gG�q��9�(v�� ������T�B)�d��<�]uz�euIbʶ��X)ۦ���Lm��%32&����΄6Ӱ�"T�\��l��,y��n�J�R4���I1���1�-^(���f&�̷��)�M[�~)�M[�.BR���ۥg�R�4	F-��fRPALJ�t�g��R0j�,�@&���bNS7�{��s�ڊpf�I˾��q>c��(�bln5j�Q>��N&�c��1ꜜ]���� s%���S-ƪ)x�t�e��j��]��\�D�t4��V�vT3����a~���8{L���ک����ղm�2˦}�<P�J�OQzt�%JQ�3qz�I!�oEH���/-�
-�F獘�vk7Ә��d+c]��h�:3*LRƾ��
��ѓ�]h�* �&+d��f�@.#�^�&д,�G�� ���R��@���ňĔ~u��J�ŧ��b��<�l��5���2���(���"�bC�ն�h��N��>�4����&W쾙����f�G�@e�c���HA�F�n&D$Ad%j�k0�3�~���p}�>�PZƅ�0&�c�
o��yT8\�U̞n��דH���- �����s�Tj�a��\/���>��L��d����r���c�D�9����Qs:H���6�h�3#�^�x��F/�ճ�V��M=���k���ig���Hf�s�sq=N�ސ��
�8L�T�9�U�*$�Y�D%F���5�jƹe݈(���E�ݛȊW�W՚���B>M���q����a�De���
eG'd�f���*L��B؜��sپ+'TR�\hւ����b��`e�h)k�٧�-^J�DbJ�4�wT�IK�|�:�j��R�^)�j!/�k�0�6�h�,�(�8'������ ���r���l�r�g��dk�LQ�Tgd��e���fe�$8=�9<NN�0��O\�ȋ&���fVRea0nK$o��]<y�EY��c�L����@��W�HD���'��凋DƂE\��"�Q�h8�S�TW���HC�)�����,����Ɏ��R�#� fG�:�502�&���M�=���+��N�y�2y��uiF̹�[i0v�'3W8�E�Z��Ԥ�F��/�ɰ!qh�z���1�+l����f�!�T���!�b�U�*�mU���t�g���z\�����k&#-����c�o���ןW�'�սv���>� �ɰn�?�WQ�	�[=c���ޖ3&r\f��dєDU� F��m������k�`�ɖ��D	�Y�Ь�����m�E�1辬\�2���8�52�-��`*4�ubʕ݌cSz�09!f��񩜔z���}�?�O�l��N���t�hD5���"R�6`����Q���>I�����1��O�|)�O�I��rM�I�òB������
ieI�$#d��M�7ܐ9��WJ��B?7��5y���cۑ�w��A�.d���+H!}Gb�?'�#%�:$���c�&�H�O�cڐT�x\�,5B�!؃G��t��1圃�r̝Ӎ�<�1�0�@�Y�Y��F�؟R���4:)嚠>[�Χ�)Z�4�)R5W�ҁ�����⺻E-��^ْ���V�',iم2Ry�@\�:e��$[i̐� ��3$�T#�?h�[�v	V�R����hg��CTg����B.���2�w��BU���w���K����9,&�)'������\�l�;1s�V/P��$(�Y?y���D����c[�����WJ��H2�ˬ��0IrI&x�5!c9���Rw�vi�l�}x޸M(�}p���ۄ�e��՗��´���I�lu0Qn}���I]k.S���Y�I�Bu����0#Ӭ���7[�5����Ϟ����x      �   �   x�ŐM�@��������%��A?��bC,��k%�o�";V�ᙁwxx�$��$_A�ר'��Ԇ�N���f��ci�=2hxMSl�ʈq%[����<r.lqf���N����~{|;d�SFu�))��>ݹ}����jK�T(������7f荛�(�S���Wk�ܖC
��tM��hy�uu�      �   �   x�͔=k�0�w��ws&`y	dj�CHJ즣�ш�#�]	��Q������ �C����	�2�W(����%^09���E�ׂ��VmM�Fwoca�_�=���9���,M��r�?4�X��**Ѳ����6�i ?���K0V69U_7(G���A9������P�h��'t��z�=����$���;g���M�d`�1L�Bya�v2��/Yҩ��
)��B>��<��      �   E  x�՚Ko�8�������p�VO9� H_�^�vM����-�~�ΐ�$RZ`�"`H2����f8/�������������������y:l��7�����N�6���}]=mi{����i��m[��������ݶ/t����n�������|��l�ZR���k���O�&~}[�y}���K�������V������#�\���i �C?}�3�D]��E������wW7�F���	�FӱP2p"�A�*p��9�0�i�J�T^��!�vvxmC�9�B6+�B*_"����t����_��+���we�U��Y22�H�@L<T�ĥ��Wi�ظ&�bj\rd�u�!�/Ӹ{1cV�32��c�����*}��x��*��հQ)kL����eM�k�W�F�v�0�� ��^t��X81�Uf�KES�2��^� C2�?٠�y�c�0�Fy9��	A�e����ra���z�N^�t*�_=$!��*��z(��q,/��X#���c|�N����1i]��p�����������E��9��%��X]L|��k��$��R|�����ۛ�S��\���.E,�h1�Fy9�֨��6��fΝi�+�u#u�� ��P3�58�+f�z���fbdnm�Ʌ%��0v���G��v��q�X,�f�R�b����`�n��kT�!���O4��EcΧTol��`VA�F��e��l*M�.�hiC�.z\�O�<���m!U�K�!I��
&�gB5��^�.��P@����K�IL*��=�<��^��Ň͸�2�<^~(<������5�I&���R���L,x�R����R})���Ҙ�|^�F��s�_Wޤ�%���aJ��Ȣ�Ӆ�ad1��󨑇9��Iu�e"�CY<S���ٲX�rg��,�Y27�Yc�rTWH����*ʷ2�����[�*�9��hRu1���̪+ \h����<�4y�.�x�3�|*���]��,/��TMki��ׇ�73aY��XE��n��,���/��؝;5��������LdA�!@_8���ɇɡ��З��^.�?���1�o�yEǋ���ԧ}�'�~w�n_]��0�      �   �  x��ZMo�:��W�ݴz��R��r�͠�% ���@[��A:R�����⽝��FYD������;L
��&e
_�`M�V���n��m}���6���з�K۝�`/��,��~��v��i1[���@.�v������7��`���4?���T�æ��=���T7���1��q��Ia�G%~m;&'� ��.,��I1�z�C0jjӕ�ph���jA�+���ܶ��s�"�O˃s�՟�T��5�m�^�E��
/_D/��xw�_�5��ÝZ[�p(�M�h)�*E2�qWH(JQ�
X�"T��a�#�e��e�ә�|k�o!�D"�qd*_&e���vN�cÁ��a&�5<<��LAU]u]U��6]i�[�Kqa
A"K�vq��́,�M�v�� ��*i��e�A��F	����|���@�}���U��U+ăfҨ3}�i��e>�<���I����0{4���q�:Z���<hf/�y�q��6���E�8Ȟ^����Y�t�����mmq%J��t�x��i�وR>�gE�y�8��%bQ�M�U]�QQ�����5��������:z��>e,�$�E�n��\a������\����I��è=�Z�����~�Ha��J�-�c�u��l&�fr���l�M�EL������Ὡa�u5�v=TAT¥��,��ǋ�[d�KU뺨}C��~|��A�´0EBуh�F�ILS8fG�b�T���8��F�alN�[W3��a�$�R׽��� ��A��t ���x9~���L8vo�����x�/+Ñ�2v�kҧ���G�<6@ɂ��p���e�*�ܧ&'ǐ'������8n�6JY��G�8K�2L6���%�q��Ǵ�:G�T�xpě,�xǵ5���sDDQ�x=� �f� �bUĪ:��� 2��Ȉ."#��W�NɆY�R>����ݤ�ǴA��1�"߂AX����%�g��b~V�T��5ڸ]�qk�1�Y���<a����n�2j�h�4��h��|u�E�S)	!J�a�r�1�R�U�-[�����s\T֭'����'1'�b�X'2����36�¦x�u�F�~���\Z��$��^FS}a��4Z_D��xD�����+����qz\U�:6fg���_F~`�      m   
   x���          o   
   x���          p   
   x���          �   [   x���v
Q���Wȭ�M-�+IL�I-V��L�Q�K�M�Q(�/�/�,H�Ts�	uV�0�QP/-�TWO-K��UE��:
~�>>��\\\ �Pl      �   
   x���          �      x��]ˎ%�q��+z'	�.d��q��B�X��!��I�(�{gDVee=�v� .�M�	����x�8�����W����_����������_�����?���������?����_�~������~��~����_������|����ھ�k��/߾�凿~�����������?~�������߾���?~��ǿ��o��W���Ef��)|����~~��gȟ� /����o�ߖ���O���u���Ï��_���~���E���Б�'���_�^R*��������, ��O�aA,�	�ˋ��X X^�^��X� �$��W��I�9|����!��7s�!I�2���	�Z��^���M��a{�@�c�i6���c\L���X�_/J~��̆E6Xr�*/=g�������\� ��#��yA���ٗ8�������;��0��a��?�K|��C�X �i/���=��
�$$=XjE�;c���O�^�g�r��/�8K��J|��P9J7�^V,���B?~?�n��ϰ�#���7g,�+�_��`I�����������S,�b˄ݽ�#x�eN_v/�B�"�HO����c�"�&�h�'$}�@�a<D�R�N�$'XP�1�˘���:���`R����G(/�/����E�zȴ�Da0����D7E%��5��)ӺR�K��N�$��A	�돢�%�|�5b�ƒ��K\n���2��.�Q��K+���%�����ذl�1�P]��K�&��e�XYI⋲#0�'d|
F<�)k�o���d������7�@�#V�_�~vd-�+=dr #�U������͍Iںvuc��Ӿ�Q�d�0c+_z��`�eB��/vS����M�i�X���zӧ�e)���-��F4�i����g4��a�1��ܿ�4�.-r^�h/V[�D/��9� �i�����Z���H3^O7P
�E7Xd�8�g@Ѥ�;=�*==� ���1��q�\�5��1KK��41iM5qo�-��dP��%:����~���	δ�����*s�z�֟�w,n��gX�K�\��"s�0��}���q�c2�r�]?����0!><@�/{�����Q^A�d ������hX��%�DK0������b�L��O7MNc���^��&�	{��h
�������F��M5L}���9#�1�2���aѤ��3 �s��?e���D d��k,,C���X8�p_�3F��9s�=ܗ�p�a_h����P&ȱ8�O1��&�k���s��)�`�eX��a��Dй��`F��i >��{0^\N�P�/� Ǒ��w:�1���i�r��\��c�#�쀥'�.��{,qxɞ�E��'=����l��-�<�%Y�,��~��4���X�#7or.�y��E�`Q���4����qN�Xj@.�dit:Z%)g��>��@��YC�e��@��e�	+��UA��3[���&��d	��F��v��k,c̺R��:�9���� ��:�6�W>*�L����}��0\aP�0AYS�!����ÍS����q4O�TL�$L�
���CB	�os�����ͦ�1�L@e���L�ĨA@M1�'��2z�T!�:}��\���MH���`���s%�TeN^^	����&�ܪ. ]W�;�<I)ns�1)�c*��&���8�+��B�0�ב�`�qy���s�J����p	��N����(���	[I��L��N���@$��z���r��]�:�	7`L׉���h�-���.h]W��D�W�F�����ԅ7vcQ�V��H.'rD��%�""�7��_a�n&͊����>�=�XVWOXh�.�BO?d��,�Z��YЦ;<��Pp���%�ЏÄ�]Ɲe4�N5<sFF��?ff��1TM_��4>gQ-�)oy��S�'#�m� c�v��j ߃i�{`",o����� �ֈ4�ڵ�����Ҵ����8�4$g-ѥ?��e������;���e�K�����Z���$q�&2�}���;�m5�G'-Q��������er�R��W8b��m6��e|�8��G,#c(��Y7����ˍ�;,�li�)�V�IM;���4��[�;]���j ʇ��LoYb�K!'m��m�S!
�K\�-g^�7i8tV��9e�(o>�>9_0"�Yr3k��=/��-�R���eT��	�����۴J���&������6G��b4��F�J{��Q��1�)��K����Wa�XS	/�Oayø!�a	�م�{L2e(%d/�$��� N�֑���'�hh��D����-�@��(^� �J���P�B������	!br#D�"	���L"LR7*K4�;�jYl�ɣ������xf�T1��/\a�WP�8��PL6H��p�.V/jA�=%���L���i��Sڞ
��.�rJ����`��	����y�����)&�叠R!?��F�Ů&�(W2|)� �L�C���`7�Ol��MЧ���J��Jh��t���:���\�m��h�1��O�8����n��6ӆH��q�삅�؅��&[!`0���|`��W�©]<a�}m&�5�VX2�R�k<Bp�W��<����@�yw�E���.`c�Dh~��g[v6�飌Q^�He��p�B��x-�o�� /�b��k��fZ��5~FD.^���VҰu&�4����`�Kg2�tF�=�2	/M��@��I)��CW���0���$�Qs)p��Z0L���f�������m�<U��ݴ�
�U���*�4qJT���C�ty�z���)�X�pN緘j䀡���)w�Pl�����ܧ��@�d����ۮD�	B��Jގ�DJ�����P��.O\3vW�VrCqR=��$����@�$�����
9ya�WPױDU��=�2Kݰ2T&Nb���S-�=/_Y������"][
a*���
*��'���xQ�Oz|��#M���� �i��a�t'�$M�R�Bq���Yڃ�*�[�"/5����/�U䷀�
���rC���
�4ɴ㿬��j����`1�A��+{0:%�@��$�3����ͳ��7�`�X���;52�0K��J3(�/)�1��SZ�o%��\)���%d��e�a�!�E� ێ�G!��>���#���c�8rwqb vD&��o��$~�n%�k嗠��UnX��>Ș��ϗ-��8���K�c��2��	eb�m��(i�_҉K�m�����1�[LE�z�燃��@!MT0��w6��E��0�y1�1����,�¢��XR/3~e�e���v�M�D!
�iM�6�ek��5t*^:�9-<�&�0��-D0]���8ר���n��g__��6�?�h�+�[Ë�DHh�j�P�u�n�Q����yG�>J[�LI��-�t D ��S�e���H%�U����RW}<�/tCiާN�6���@�̷�����n�K��2�6�إ�����:np�▪�t����.��nMH� )� ���6��[�����$wq���C�qV�w��Dx�������b"�8#���OǔK�Oh �8X�9��� \�-��+^&�"�E�Ҫ��mؿs�6���������������7.ނ��LP_��gd���'�b]z�����QȤ:�X�q~X�7��UE�T��>`�S���� ��bb�Dr=}N0)����!�B�^p`7rY�;�s��
]�sKJN@�|�s�tO7D���9�Y!\�jn��1Pt4��'W��#K�uI��^�z�ꤼԴ �j� em�sĹ�
ރ���h��}��rw��B�LY��T  �NĢ��H�(�������	K�W�_SS%��i.w��q�$�qp��HF/A���}��{Q���X��`.��;,n�'�T�Z`�~�"o�x)�E[�m��p���hW^)x���to�E|ρ]��=�Ά�<k�e sĢ�G�À��X��
�xȎX��FŦ�n��Yo*�P}s_��~�    X���я"*��|��������3�ElQ�<���}�/u6�^�d,V�y<�eY(�Zf�>x<�*R��j� b#���*UtVy@�R�?�͍�5�^��[�f�'C!�˥�����'�p�D3	�p� �E4��@�e�����g^&�0;��}��Kn�r�r�Y>�ry݋F�^F@�c��*�1?��)-�o��s�*�5N�S�B~�M��e�_O_ނ��3��	y�ס@y�0��囤�j<$�I�����"4�+����b�������Dن'XjZV��x)�&m�`���;7X��<�.L�-u\���,Y= h��(�5[��0��ҷ-��,��f'k�W,����I�V���)��:��-��LD�D~<De�ص�g#��	�֛s�������� Ϊf<�gԕJ���q�oxLD�v��(���7R�O�T8=t���x���C�t-7�Nw60�f'�hY'�g{����M>NT=Kd^(&� Z)&P3�9�qP��]�e�jQ^8��y�y�,6�[%݃]�F&þ��F/7�ۄ��ʒ��˘^�ts�I]�x�K�:t[�v�J
Fl뮗Qj�c��0b�Y���^�q����{�hj�\����_��Wy�l��e|���f��Yl8&�4:�4�1=L1��kOj4LT�I/�~-�_����O�H9ĵ����
�h ��jg�i\�9Mb�Ǩ��.�ˆ`�@F���G�s2�f9���)jJ63O6DF�@&`#hy�bP���eV�C7l��mRd�Z�d'O2�t �W�ɲZ��)�9%�&J���C��xm��b$n�d3��z>��	�3�N(Zȸ^��Q��L\��I���6�:�����]��ɴҋ�k"��5ُ]�u�������8�tB�} ������2�>��b��%a������n9�Tx�g�b�>�$r�t}q'g�Yn�\*�!��� H���)o�����he�,�Y<`��p��!� k�[V�a5�4�p�Q�eI
��Q|�Ee��,�tHRs�鐦 �,8���*oO���^�^��Idf'��w�/�W���%�!:�/ɴ��:h�͇�(i&#���I؏�b��7�jy�e�����?<kk�jE�"�O��,p4��q3�m��ڕ��������`Y讃���Z�҃���߰j�O^ZxBI�p �����v	�[�(M�y/���uu3��A�/Fu]H"�?bdI��b��W���4'r$D݉V��-�t �־����Y��rJ�	��{_t*��^�U�����qv4AN���`���Sk"���Ee�Hb��r D$>e��I��F��RD۫�`��R�T����:�����r�.��;����u�>c��IYX�#��*50v�>�*'�iTA���P)&;�*�<p�N�w�Q}:�����W���]$��(<%�=��\%]{Tꎗ����Rײp���/T g �&�]�qn�Q�ݓ&��&��'�W2�(Y�K���:z���i�����EH<��A�]s`����/�:�bq�xQ^In|��2����H+�RN�_4�1v��d��ӗ}�k9].|^��0��7�g�WMH�󀥱)B�)NZ*�8+In��U���d܃�If+��.��cvC�e��9#�15�h�b�I�8�|tN��t���X�;`�v���pzSzUU�,���+/Nba�!���ܵL>8�&Z�!��]��-� 	R�K6�ku��M3-�C/8��d\Ea�n�I�.:}��K����<��l9�%4��-��h��f�V�R�v7+6�b��Wr1aێ�2-���1t+��)-ԻѫO؆��z��Ƅ�m�ׯ"`�_�$N)d/S�E�|Ǵ�@��-�T���[�Gv��l�u��v	ޑ��
�Xm�J�D�ݤ���M��l\h>���0�@6X����,r���+?�n� �����k�¦��0�GtNbXJa�`��:^�<r��:�E�7�a����K�������W0M�Bt�fЮ�x��Y73��^�e��L�< ��d��C^���L�*F�����Jp��P�~�{Ly�%1x�A�=n�m�o0ч��yQŔK����x�X�~��h(��7�L��ɋdB�fF�'u4IZ�B���釯Pz��L5�n�T��#&z�L)QD/
%�Vs�I��N��ۇ�u��D��*xx� 0\�|<�!N���WC�%�h����땊X�\P e�<UZ���/��<� ��]�`�	�2��`[
��J�	�r�����b*ˢ>Wt4L������,�$�e9$�#�m9��U���H�FFw�|�R��0��F)��e�%��م�lc��S��I�'��*3�Me���>}nV_r���K� �P/��T=�P܀j���yyJ��Kh�՗?�*0��̧�1F�u�i1�Z,^b*�h�.0	��x7v��%ʄ���|6&mU�-ȍV��6"HO%�(O�mE6�ȃjm9p[�t�>���])�\u�X�o����̆�[�I��n�^��F��L}�i��+�7����{0nJ��r�e���δ����j�h�����,��w�r�%Ե�ɏ���(�oi���0� ��)c�{�t�HC�K}}��+���g���b���@�b�r�ɖ�'QZ��"Z�d����U���&w.���T�ǋx���*:���ӽ뗙��q�5&��R���
����f�t,Z�m��m�~y��/�L��b����P_��d�s`�R��L���&yyrk��2݄�����37沃9^�Я������X�J�~�ۖ�4ˣ: SE��g؇�mS ��jN�W�c�#��h\)u��q���<��1�Ub�<�x	�b�y�O�X����K�,:�4�0`Ir��b�SGH��79���rv��t�h��PXx6�_6�N�;RZ���0ɘ*?�����%���A���>KR�Љ���0�i/x�/�� g����z������Z��-+3CF,�e�$�,�)s���T���� �����AO`r;^��"�Y8�&��ס�6Y�y�0�P��k� �����>ɮ��/oY[�`fd�*���χ�g(02JP猔Q�d����+�:
a��� 
��;(�����U�U���kc�������3(:dX���I��A��F��%w�
�������!\���S�r�%�����"^TV
^H��
����K�P7^	H�vR�+��.������_��zF��S�B	���J��>����܋P/C�%�L�L&�?�!{�T_�7�Xq�ť���@�� x�� �:���� x9�ߪ8�2=%��P�߉���"e�P�7w��-(LC� n@	]?�W�O:`,~
��fj_Ӿ�c!/���½��,EcL~@�Us'���?3�w�Ҫ|R�&NEđ��
<b�0�8��~��%#���ek�d�:�k��~�>n�S<s�/Aa������(̵���z��H��`�q����`�\b*�&^t0�Ӣ��\��RZI���O��7;�j�Q��}��J���aó1e��U;"����=\�|+��X�oZ��͐��5aa/qQ�c$W�׎�{r�U�n`�{S�L�U�1���>���~������|<�S^Tʹ�p�j��P/v,�3.����!{a��ݳ�L� � �OW���+#�N	2��&~�����r롸�r���������1A�)s�i�Q�I�Q-��Q@An;M�IMI �)��_ʠ2��>Hя84Z�.�sYp(n*C���w�hb��~�	��H�F���$)���e���h�
B����y�Yg�N� :�@p�|�bێ�`�˦�9�aO�I�S^�l(�4� /`�:��0�h�0F�<�&Jz̴~��Δ��ʈ%������^��3k�+��!rf�Y��E6̎�PJ���â:UҪ�.�HSD(s7r#�l$v�4^h�ǭ�㐷�G��cq#��gY}&�2?3k�*u�ͅ�Q�����X$�s�r���#,ԇqvX��&� N  y�ј��f<wgl֨n&���``��u0�����o�IU 5,^.̚�lØ���Ð�����#��П�G0��Qi��^�`��X�]NMq����Ѐ�`��teM�ZI&�#j��0���$�F�Yy��26	�Yq{H��tY�\��W�S�u,��y6E�Ʈ�Q�d��tX�mJ�T-�\�yȸ�����깆�*��3�hũ枩�`�3�,���,G�ʆ�`Ii��X`�t}>�2��O<��鲗���.��p��זH.��k�/�,�X���C{�QW���2�W05�w�`�I	�f��)-������Dc_JX��&��X��)�D��9Kho�-w�I�@���SSv Ě&Z�C�q���4�]Tbm���[��do��MU0w��c�#�X:7α�i[[�߆��n�J��.�b�Z�w���t^�un2I�H��A3�q@�Z����(�C9F6O�d�觤FYip*��� 5��W�|V`0�H~n�E��T�!h%aJY�xo�Yh��T�T�"��)J=�ad�3/o���+��T�7��,�|��������~�xn-      �   s  x��XQs�8~��hn&�$��@�'Bh�IHr�$��t2
R���\[nJ3�ﷲ��1�$�#�w��~���%�z��ϐݺ�h�6��픇!�
rX���(L~�;t�9���۝�h�$%
�/�v*ȴ*Ȩ��G|'�)n?>U���.�O%��=ʦ�������Wp��TN��NG�e�
X	�4T���+FT:��蔯�r(G0\Oh�^}�x0K��p�D_���'N(E��.���yӬ`�%^�_>�W�#1�#�Y��Xa��V^���ܓ��- �|��B3q\J��"�]��3*ii:n_?b�A��e���n8�W���ʌ����S*�jy�� �S��`�7�Fj���>���y&q^��3v��M)$�����`� `*
`�i<%IH��q���!�v*u/�йuy&�|@���T��O=�>.�Tr���u[<���ྪ�K�4ڡ��{}��M���)R.v�����Y���á�K~ԗj �-����=���FL���Z�����ƶ��/��w;Z�,�}?x)Gʚ«D���ZI�*a&[�"���g��V=[����"5���ڄG�t�m�Fo��g����۱q��7>��=v��u>0�t�Nw�;8���*!�m*��%�d|R20چ:�!gX!�	`�r��nF�*)Ɔ��e����a$e?�N���C�u;�3����ݻ�%�=�������!͆Y%����ǃ�~ϷϺx��M��V�+|4�f�x�:h�$�~�XU����.P��3m�����vg�y��p	=���f�,�i.R�CȾNq)�C�#��֬��`��~X�4J�/�h�P�Tc���а�y-���f�Fլ=��C\35ı�Y�*%7����Q�6�W�~��ԗ3t""o�GB�j:f�����'���kZ[&�����:���*7�HO�;ؑ��<{�n�ܬ�L'FG^�:Ǥ�2���\<����4%��`͗N�.����K�-=��������;�%�[��k��3�kM�0��Q����m��(-ꎩ����z��	��DOlm�eXKͫ��B�b�suԒ\}i���"Ӥ�i���5k��Z��5[��q-�3{��^�Ar*�k�,0t0C=�\Wd���<���Y��c]�t!z-��(��u��>��Sk�
�=DS�@��_�D�ĕ�+v�K���i�Ѩ֗u���N������
]Ӫcaw��bgF$q� �98p���p�U�N�+���ԧ����H̠Y0�<��ZaN���5
k��Q&ϭ�/�8!�J�srQ\��Ew]B����4�����t�i3��Ň=���ݷ��i���{si��t�7?��d�q����,;��ǯ���	?���͛>�GF      �   
   x���          w   j   x���v
Q���W((M��L�+(�O��I-V��L�Q�K�M�QHL.�,K�Ts�	uV�0�QPOL���S�Q()*Mմ��$�$#�I�ũEd4(%57a =�C�      �   �   x����
�0 л_��
2������p0ݮ��uQ���Ϯ��I	%Px	I���o5e}���e{X�YȱW�����"���K�^��\�����W��|��g�@t9���\�9��uo�mS���u��9�6w6�������)\F�v��+L]�0'�7
�/�|��P�0!6�)�x���j�ӿ�������}�lD      �   �  x��]Ko�6��W,|I�Q�&�����@^������e-�
E%1���R�ER)����$g8�̐��P��p���^]|���J�m��f��տ/V�}���j������?��juJ���_W��d�-d�D��NϪf)����)���G_�fU��ߛ�.Q/߲Y��'0)ex\�,�hp��!�:â��	��D�9Q��]��%+������$ݒ������Ǚ�'�b2	���#�cQ}��.�@'�Rr���Ft�#����
�DY��X�V���g��݌Y)��<�'�i6�� э�w(��{����]
�����U��*|�Lj������"�Xv�w�u��(��[�~,�])Z�UY+�Ruʙ�
SL�l<{�K�"X���IY�ʥ�R�Q��hY�Ю0�	c���\��y�o{�G�i��*]���X�JGދS���]�T��#�����]�[��-�4A��-n�� �x}E!BiG߰�%N#G#��<a�$2/�2�SB:Q�*.��=��Tt_����0�(�!9�5n<�1�B�#H�d�Tci��95}#�6·�ĕ882y-�hr��19���(�k�j�l�4}!oF��K�I(�;�gg��^��Y��|Ǆ�j��$x3������xY~{���I���{�)�*qp䀅x���e��e@�9�LV?��g�<���Y%���qAf��n����������5�>O��7�C�E���2@o�}
�"��M��}ͨ "V�-^��Q��Cg�wQ���I#`9��DzwV�v3J�Š�)l��8ZD� 0�9a������*�!S��ſd��[��t�?J3�^��E\�@�Z/�իTyY����l:��lQ�$��[9+�>�[A�{�Y#Oc�����C;�3��*�����)�wnl7��rχE$<QO�3����f+�-����v��*&�]����#ž�!�R�+�L<0���� ��W_c�,���<�Q��r��Ѳ������܋���=���&��*6�M!�8h��fЀ�e�Ȣ���p� �8C�'+-����S��l��(�x�WNn�6�>��q�>d��Q����r-4�)&�vZ����sAa61PIM���-�5œ
�Q٧_@�y���֐����ï�rJl�[%�9Wf�\`�}��]z�� B[�bv�a�h<�xnK��	�EO�Y�n6潋�;,2ZEʲ�~��Z���Vj���E��W<{��
1�E�ܲ)��aW��1lx �puP�(���ǜ�(ϸ��Y�y�OP��Ym�9�*��Xβ��lyƜ��+K\}!O�t)$1�2۝�z���G���՝�hԔ�=$0��������gD��1d�l7T9*-^5w_p/�"���?P��mT6���fǃ��zGs:���;��vG�L���T׭��p�51P��8Oh�ɱ��L,��^��������
��l��4�/	J�F���
��a7�{Pځ��S�|~̑���ϋ=��?����vi~ֈlA��e��4{���%����Œ��p|i���3��If��Z-y��:��H��$g���P\ru���f��k�FRNJ��y3�k_=�~��7&}�hk�}�3;No��K��w)� 9v)P��~v���	��}�4��B�ϛF�iY�3'�4t ���"ƀ"�t�[�txEOsj��="�Q?�Wd���!������I ��#��0T/�/��nw��7F����f�C7wf8k�G�>g�Q��Ȇ�.Κ=[f���%y����+�o|����+�f���g��*����ۏ���4ze?-ϙ6���1>���ơZ�JW���U��bF=	o�����}`�����%ڟJ3=_|u�%���ǲ�Q�O�v#���s_t��>��=�[>'�;d��Es-D�߲��-�m�͵`~�����U�l�pH�>���Qj0T�#��x�`p_��3�%�,�vlq�4�@E�ҖX9*��l���]�9� 
�Q�5�V��,�l�)bgNy9&_��m�D-�.���L�v$��|c������ꢝ�LU������*�h�5�g_B�FZV����������g`&����wg�^\W�֌sK���sH������c�����?���CV- ���ѷ�܂ׯ~QY$���5�Ʈ�>N�7:xL��0���N�>3�y��
M�� 9��h�:ں�ό�h�e2*EU�����?[���δ�r��@l���GItr���o'''�,s�      �   
   x���          �   
   x���          �   �   x���v
Q���W((M��L�+I-.Q�()��K�NM�Q �J�4�}B]�4ԍ�t,t�������,M,���uPd�Qd��5��<ɲ�R��\�h���XS#=cscC3��0YY��\\ ��8�      �   r   x���v
Q���W((M��L�+�-P�H+�ύOI,I�Q(ɇ2�r���5�}B]�4ԍ-u�t���L�-���u�FPY#=#SS��_����5 i� t      O   �  x��Xio�H��~j=)�jbjw���}	[���TU.��`�����ӯ�tz��1��u�9��s�&���L��C�|O[Id¨�s�����S,���[����|��:�f�n�(:����V&��盌���秗�UT,���04����� ���Oł/����������-�ҟ���O?��7��ެ1)�|��(�)��7�s�	���|k��Et���-���+R_!������e�W�͓�ǃp�9���>��m(�.�gS���/�Q1��@~�-��-Sn1� ��D��*�t`y~��{_��ʄ�I��l#�0]�^�Ͽ��K�c��j�ƃ�qd��ZH"Sk�9C�0D1�5c2GDW/J59�a5�mr�&�6[�8��'��.��U��-��̆߉���B\ �Y	��y`?#�4�ce4D6��`��V2�^C%m X�zk�Y�r�v�k�]��h�0w�4Yb��s���F��i﷛w��嵏P�2�eB,H���>���j�Q���y�4�� L�t��D��Dp�].��J�����10^TW �ǋ���˧�&�F�C��ƛ;H��q�/;v\��6Yy?D�S��CE�p��$������9�������&7��P�L�$/~c#1#�:�R�\�8)�c��C�{[AO�Y�贜��Y#k���35���~{��k	���Mw�a^� .���0Ή�}��8E���!���D,3"D��r`���AFB�&�J� D�"b����z,tcb�W���e��}IM{����7t�L���a��Żm�����?� &el[6ù$����kO�~�
�����
|]�i�%F��(,�1ԶM����z�����������hu�A|���p�<4g�nm2Up^U'ë�`� ���rYP}�߂�{��z&�g����1� q�t es� ������8G����pM%ܲ���dA	��F��9��y|�GU�&���!�v˦$ǀS��|�^��8�y I��D
 �"�.�f  +��8X����:�4��t���h|%}{A>ċMo]u�Q�����^�ݱ�{�������E��́�x�FC�9].���s�N�J�eL�0�֐���>�y�,�:�EDP���"L;Ո0m���1�W�j��fw�[����t�Q<�N�Rк�Ն��
QӋ�=�i��+�D!&!e-��wm���t�֥7��J��[�'t��ˤ
�i��ƩSgBq��n*�ܵsdTjf���Fg�7z��*����-�8˥�ɪ-���5��M#����gC�����1�l��J��/v�s�	����/��|j(�c!�ڕځ Gk�RW�;��,��ù�y�K\�8���c���zRQ����O'�v'��C2��Q{5,��LH�}������t��=J#돯���b"�C��9 D1�*j��s� �'��F�R��E���ӻ`��L.�VXj�f�2�J��n�۫ڷ������������\���11}������_��8)Ж#�tml�1`B�rdj����h����5����*�����ڏ0
v=>��Ui�?<LyНvjy2^,;��9.*o�VX��?���|�/�R��      �   
   x���         