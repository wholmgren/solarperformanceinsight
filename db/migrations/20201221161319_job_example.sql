-- migrate:up
drop procedure add_example_data;
create procedure _add_example_data_0 ()
  comment 'Add example data to the database'
  modifies sql data
begin
  set @userid = uuid_to_bin('17fbf1c6-34bd-11eb-af43-f4939feddd82', 1);
  set @otheruser = uuid_to_bin('972084d4-34cd-11eb-8f13-f4939feddd82', 1);
  set @sysid = uuid_to_bin('6b61d9ac-2e89-11eb-be2a-4dc7a6bcd0d9', 1);
  set @othersysid = uuid_to_bin('6513485a-34cd-11eb-8f13-f4939feddd82', 1);
  set @extime = timestamp('2020-12-01 01:23');
  set @sysdef = '{
       "name": "Test PV System",
       "latitude": 33.98,
       "longitude": -115.323,
       "elevation": 2300,
       "inverters": [
         {
           "name": "Inverter 1",
           "make_model": "ABB__MICRO_0_25_I_OUTD_US_208__208V_",
           "inverter_parameters": {
             "Pso": 2.08961,
             "Paco": 250,
             "Pdco": 259.589,
             "Vdco": 40,
             "C0": -4.1e-05,
             "C1": -9.1e-05,
             "C2": 0.000494,
             "C3": -0.013171,
             "Pnt": 0.075
           },
           "losses": {},
           "arrays": [
             {
               "name": "Array 1",
               "make_model": "Canadian_Solar_Inc__CS5P_220M",
               "albedo": 0.2,
               "modules_per_string": 7,
               "strings": 5,
               "tracking": {
                 "tilt": 20.0,
                 "azimuth": 180.0
               },
               "temperature_model_parameters": {
                 "u_c": 29.0,
                 "u_v": 0.0,
                 "eta_m": 0.1,
                 "alpha_absorption": 0.9
               },
               "module_parameters": {
                 "alpha_sc": 0.004539,
                 "gamma_ref": 1.2,
                 "mu_gamma": -0.003,
                 "I_L_ref": 5.11426,
                 "I_o_ref": 8.10251e-10,
                 "R_sh_ref": 381.254,
                 "R_s": 1.06602,
                 "R_sh_0": 400.0,
                 "cells_in_series": 96
               }
             }
           ]
         }
       ]
     }';

  insert into users (auth0_id, id, created_at) values (
    'auth0|5fa9596ccf64f9006e841a3a', @userid, @extime
  ),(
    'auth0|invalid', @otheruser, @extime
    );
  insert into systems (id, user_id, name, definition, created_at, modified_at) values (
    @sysid, @userid, 'Test PV System', @sysdef, @extime, @extime
  ),(
    @othersysid, @otheruser, 'Other system', '{}', @extime, @extime
    );
end;

create procedure _add_example_data_1 ()
  modifies sql data
begin
  set @jobid = uuid_to_bin('e1772e64-43ac-11eb-92c2-f4939feddd82', 1);
  set @otherjobid = uuid_to_bin('7f13ab34-43ad-11eb-80a2-f4939feddd82', 1);
  set @jobdataid0 = uuid_to_bin('ecaa5a40-43ac-11eb-a75d-f4939feddd82', 1);
  set @jobdataid1 = uuid_to_bin('f9ef0c00-43ac-11eb-8931-f4939feddd82', 1);
  set @userid = uuid_to_bin('17fbf1c6-34bd-11eb-af43-f4939feddd82', 1);
  set @otheruser = uuid_to_bin('972084d4-34cd-11eb-8f13-f4939feddd82', 1);
  set @sysid = uuid_to_bin('6b61d9ac-2e89-11eb-be2a-4dc7a6bcd0d9', 1);
  set @othersysid = uuid_to_bin('6513485a-34cd-11eb-8f13-f4939feddd82', 1);
  set @extime = timestamp('2020-12-11 19:52');
  set @modtime = timestamp('2020-12-11 20:00');

  set @sysjson = (select cast(definition as json) from systems where id = @sysid);
  set @jobparams = '{"parameters": {
      "system_id": "6b61d9ac-2e89-11eb-be2a-4dc7a6bcd0d9",
      "time_parameters": {
        "start": "2020-01-01T00:00:00+00:00",
        "end": "2020-12-31T23:59:59+00:00",
        "step": "15:00",
        "timezone": "UTC"
      },
      "weather_granularity": "array",
      "job_type": {
        "compare": "predicted and actual performance",
        "performance_granularity": "inverter"
      },
      "irradiance_type": "poa",
      "temperature_type": "module"}}';
  -- odd annoying way to make sure system def is also json
  set @jobjson = json_set(@jobparams, '$.system_definition', json_value(@sysjson, '$' returning json));

  insert into jobs (id, user_id, system_id, definition, status, created_at, modified_at) values (
    @jobid, @userid, @sysid, @jobjson, 'created', @extime, @extime), (
      @otherjobid, @otheruser, @othersysid, @jobjson, 'created', @extime, @extime);
  insert into job_data (id, job_id, schema_path, type, created_at, modified_at) values (
    @jobdataid0, @jobid, '/inverters/0/arrays/0', 'original weather data', @extime, @extime), (
      @jobdataid1, @jobid, '/inverters/0', 'actual performance data', @extime, @extime);
  update job_data set present = true, data = 'binary data blob', format = 'application/vnd.apache.arrow.file', filename = 'inverter_0_performance.arrow', modified_at = @modtime  where id = @jobdataid1;
end;

create procedure add_example_data ()
  modifies sql data
begin
  CALL _add_example_data_0;
  CALL _add_example_data_1;
end;


drop procedure remove_example_data;
create procedure _remove_example_data_0 ()
  comment 'Remove example data from the database'
  modifies sql data
begin
  set @userid = uuid_to_bin('17fbf1c6-34bd-11eb-af43-f4939feddd82', 1);
  set @sysid = uuid_to_bin('6b61d9ac-2e89-11eb-be2a-4dc7a6bcd0d9', 1);
  set @othersysid = uuid_to_bin('6513485a-34cd-11eb-8f13-f4939feddd82', 1);
  set @otheruser = uuid_to_bin('972084d4-34cd-11eb-8f13-f4939feddd82', 1);

  delete from systems where id = @sysid;
  delete from systems where id = @othersysid;
  delete from users where id = @userid;
  delete from users where id = @otheruser;
end;

create procedure _remove_example_data_1 ()
  modifies sql data
begin
  set @jobid = uuid_to_bin('e1772e64-43ac-11eb-92c2-f4939feddd82', 1);
  set @otherjobid = uuid_to_bin('7f13ab34-43ad-11eb-80a2-f4939feddd82', 1);
  delete from jobs where id = @jobid;
  delete from jobs where id = @otherjobid;
end;

create procedure remove_example_data ()
  modifies sql data
begin
  CALL _remove_example_data_0;
  CALL _remove_example_data_1;
end;

-- migrate:down
drop procedure _add_example_data_0;
drop procedure _add_example_data_1;
drop procedure _remove_example_data_0;
drop procedure _remove_example_data_1;

drop procedure add_example_data;
create procedure add_example_data ()
  comment 'Add example data to the database'
  modifies sql data
begin
  set @userid = uuid_to_bin('17fbf1c6-34bd-11eb-af43-f4939feddd82', 1);
  set @otheruser = uuid_to_bin('972084d4-34cd-11eb-8f13-f4939feddd82', 1);
  set @sysid = uuid_to_bin('6b61d9ac-2e89-11eb-be2a-4dc7a6bcd0d9', 1);
  set @othersysid = uuid_to_bin('6513485a-34cd-11eb-8f13-f4939feddd82', 1);
  set @extime = timestamp('2020-12-01 01:23');
  set @sysdef = '{
       "name": "Test PV System",
       "latitude": 33.98,
       "longitude": -115.323,
       "elevation": 2300,
       "inverters": [
         {
           "name": "Inverter 1",
           "make_model": "ABB__MICRO_0_25_I_OUTD_US_208__208V_",
           "inverter_parameters": {
             "Pso": 2.08961,
             "Paco": 250,
             "Pdco": 259.589,
             "Vdco": 40,
             "C0": -4.1e-05,
             "C1": -9.1e-05,
             "C2": 0.000494,
             "C3": -0.013171,
             "Pnt": 0.075
           },
           "losses": {},
           "arrays": [
             {
               "name": "Array 1",
               "make_model": "Canadian_Solar_Inc__CS5P_220M",
               "albedo": 0.2,
               "modules_per_string": 7,
               "strings": 5,
               "tracking": {
                 "tilt": 20.0,
                 "azimuth": 180.0
               },
               "temperature_model_parameters": {
                 "u_c": 29.0,
                 "u_v": 0.0,
                 "eta_m": 0.1,
                 "alpha_absorption": 0.9
               },
               "module_parameters": {
                 "alpha_sc": 0.004539,
                 "gamma_ref": 1.2,
                 "mu_gamma": -0.003,
                 "I_L_ref": 5.11426,
                 "I_o_ref": 8.10251e-10,
                 "R_sh_ref": 381.254,
                 "R_s": 1.06602,
                 "R_sh_0": 400.0,
                 "cells_in_series": 96
               }
             }
           ]
         }
       ]
     }';
  insert into users (auth0_id, id, created_at) values (
    'auth0|5fa9596ccf64f9006e841a3a', @userid, @extime
  ),(
    'auth0|invalid', @otheruser, @extime
    );
  insert into systems (id, user_id, name, definition, created_at, modified_at) values (
    @sysid, @userid, 'Test PV System', @sysdef, @extime, @extime
  ),(
    @othersysid, @otheruser, 'Other system', '{}', @extime, @extime
    );
end;


drop procedure remove_example_data;
create procedure remove_example_data ()
  comment 'Remove example data from the database'
  modifies sql data
begin
  set @userid = uuid_to_bin('17fbf1c6-34bd-11eb-af43-f4939feddd82', 1);
  set @sysid = uuid_to_bin('6b61d9ac-2e89-11eb-be2a-4dc7a6bcd0d9', 1);
  set @othersysid = uuid_to_bin('6513485a-34cd-11eb-8f13-f4939feddd82', 1);
  set @otheruser = uuid_to_bin('972084d4-34cd-11eb-8f13-f4939feddd82', 1);

  delete from systems where id = @sysid;
  delete from systems where id = @othersysid;
  delete from users where id = @userid;
  delete from users where id = @otheruser;
end;
