SELECT department.department_name, AVG(compensation.vacation_days) FROM
    professor 
    INNER JOIN department ON department.id = professor.department_id 
    INNER JOIN compensation ON professor.id = compensation.professor_id
    GROUP BY department.id;
    
/* result

Transfiguration,2.0
Defence Against the Dark Arts,9.0
Study of Ancient Runes,8.0
Care of Magical Creatures,13.0

*/