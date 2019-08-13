DROP TABLE IF EXISTS professor;

CREATE TABLE professor (id integer, professor text, department_id integer);

DROP TABLE IF EXISTS department;

CREATE TABLE department (id integer, department_name text);

DROP TABLE IF EXISTS compensation;

CREATE TABLE compensation (id integer, professor_id integer, salary integer, vacation_days integer);
