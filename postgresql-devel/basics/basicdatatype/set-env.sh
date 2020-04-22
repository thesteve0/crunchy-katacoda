#!/usr/bin/bash

echo 'please wait while we prep the environment (should take about 10 seconds)'
echo 'starting the database'
docker network create mybridge

docker run -d --network mybridge -p 5432:5432 -e PG_USER=groot -e PG_PASSWORD=password -e PG_DATABASE=workshop --name=pgsql crunchydata/crunchy-postgres-appdev:latest

until PGPASSWORD="password" psql -h localhost -U groot -f employees-ddl.sql workshop &> /dev/null; do
  echo >&2 "$(date +%Y%m%dt%H%M%S) Waiting for Postgres to start"
  sleep 1
done

cat <<EOF > employees-ddl.sql
-- Employee table
CREATE TABLE employee (
    empid serial 
        CONSTRAINT employee_id_pk PRIMARY KEY,
    employee_ssn VARCHAR (10) 
        CONSTRAINT employee_ak UNIQUE NOT NULL,
    employee_first_name CHAR (35) NOT NULL,
    employee_last_name CHAR (50) NOT NULL,
    employee_hire_date date NOT NULL,
    employee_termination_datetime timestamp with time zone
);
-- Department table
CREATE TABLE department (
department_number integer 
    CONSTRAINT department_number_pk 
        PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
department_name VARCHAR (50) 
    CONSTRAINT department_ak UNIQUE NOT NULL
);
-- Employee - Department table
CREATE TABLE employee_department_asc (
    employee_id integer not null,
    department_number integer not null,
    employee_department_start_date date not null,
    employee_department_end_date date null,
        CONSTRAINT employee_department_pk 
            PRIMARY KEY (employee_id, department_number),
        CONSTRAINT employee_id_fk 
            FOREIGN KEY (employee_id) REFERENCES employee (empid),
        CONSTRAINT department_number_fk 
            FOREIGN KEY (department_number) REFERENCES department (department_number) 
);
CREATE INDEX department_number_idx on employee_department_asc (department_number);
-- Employee Salary History
CREATE TABLE employee_salary_hist (
    employee_id integer not null,
    employee_salary_start_date date not null,
    employee_salary_amount numeric(13,2) 
        CONSTRAINT salary_ck1 CHECK (employee_salary_amount > 1000),
    employee_salary_end_date date null,
        CONSTRAINT employee_salary_pk 
            PRIMARY KEY (employee_id, employee_salary_start_date),
        CONSTRAINT employee_id_fk1 
            FOREIGN KEY (employee_id) REFERENCES employee (empid)
);
EOF

cat <<EOF > employees-data.sql
-- Add Employees
INSERT INTO employee (employee_ssn, employee_first_name, employee_last_name, employee_hire_date)
VALUES  ('111111111', 'John', 'Smith', current_date),
        ( '111111112', 'Mary', 'Smith', current_date),
        ( '111111113', 'Arnold', 'Jackson', current_date),
        ( '111111114', 'Jeffrey', 'Westman', current_date),
        ( '111111115', 'Bob', 'Box', current_date)
;
-- Add Departments
INSERT INTO department (department_name)
VALUES  ('SALES'),
        ('PAYROLL'),
        ('RESEARCH'),
        ('MARKETING'),
        ('GRAPHICS'),
        ('OPERATIONS'),
        ('APPLICATION DEVELOPMENT'),
        ('ACCOUNTING')
;
-- Add Employee - Department assignments
INSERT INTO employee_department_asc (
    employee_id, department_number, employee_department_start_date
    )
VALUES (
        (SELECT empid FROM employee 
            WHERE employee_first_name = 'John' AND employee_last_name = 'Smith'
        ),
        (SELECT department_number FROM department 
            WHERE department_name = 'SALES'
        ), 
        current_date
    ),
    (
        (SELECT empid FROM employee 
            WHERE employee_first_name = 'Mary' AND employee_last_name = 'Smith'
        ),
        (SELECT department_number FROM department 
            WHERE department_name = 'RESEARCH'),
        current_date
    ),
    (
        (SELECT empid FROM employee 
            WHERE employee_first_name = 'Arnold' AND employee_last_name = 'Jackson'
        ),
        (SELECT department_number FROM department 
            WHERE department_name = 'ACCOUNTING'),
        current_date
    ),
    (
        (SELECT empid FROM employee 
            WHERE employee_first_name = 'Jeffrey' AND employee_last_name = 'Westman'
        ),
        (SELECT department_number FROM department 
            WHERE department_name = 'ACCOUNTING'),
        current_date
    )
;
-- Add salary history
INSERT INTO employee_salary_hist (employee_id, employee_salary_start_date, employee_salary_amount, employee_salary_end_date)
SELECT 1, '2016-03-01'::date , 40000.00, '2017-02-28'::date
UNION
SELECT 1, '2017-03-01'::date , 50000.00, null
UNION
SELECT 2, '2016-03-01'::date , 40000.00, '2017-02-28'::date
UNION
SELECT 2, '2016-04-01'::date , 40000.00, null
UNION
SELECT 3, '2016-03-01'::date , 40000.00, null
UNION
SELECT 4, '2016-03-01'::date , 40000.00, null
;
EOF

echo 'loading employee schema'
PGPASSWORD="password" psql -h localhost -U groot -f employees-ddl.sql workshop

echo 'loading employees data'
PGPASSWORD="password" psql -h localhost -U groot -f employees-data.sql workshop

echo 'finished loading employees data'

clear

: 'ready to go!'
