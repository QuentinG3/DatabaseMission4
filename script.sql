-- Summary Ticket
SELECT name,sum AS "quantity" ,price AS "unit price",price*sum AS "total price" FROM 
	(SELECT SUM(qty),drink FROM ORDERED_DRINK,ORDERS WHERE ORDERS.id=ORDERED_DRINK.orders AND ORDERS.client=1 GROUP BY drink) AS T1, DRINK
	WHERE DRINK.id = T1.drink;

-- Total to pay
/*
SELECT SUM(price*sum) AS "total price" FROM 
	(SELECT SUM(qty),drink FROM ORDERED_DRINK,ORDERS WHERE ORDERS.id=ORDERED_DRINK.orders AND ORDERS.client=1 GROUP BY drink) AS T1, DRINK
	WHERE DRINK.id = T1.drink;*/