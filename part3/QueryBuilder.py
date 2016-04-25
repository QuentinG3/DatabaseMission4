from sqlalchemy import *
from DatabaseException import *
from datetime import datetime

#Creating table name constants
CLIENT_TABLE = "client"
DRINK_TABLE = "drink"
EMPLACEMENT_TABLE = "emplacement"
ORDERED_DRINK_TABLE = "ordered_drink"
ORDERS_TABLE = "orders"
PAYMENT_TABLE = "payment"
CLIENT_EMPLACEMENT_TABLE = "client_emplacement"

#Creating client table field name constants
ID_FIELD_CLIENT = "id"

#Creating emplacement field name constants
ID_FIELD_EMPLACEMENT = "id"

#Creating client_emplacement field name constants
CLIENT_FIELD_CLIENT_EMPLACEMENT = "client"
EMPLACEMENT_FIELD_CLIENT_EMPLACEMENT = "emplacement"

#Creating payement field name constants
ID_FIELD_PAYMENT = "id"
AMOUNT_FIELD_PAYMENT = "amount"
CLIENT_FIELD_PAYMENT = "client"

#Creating order field name constants
ID_FIELD_ORDER = "id"
TIME_FIELD_ORDER = "time"
CLIENT_FIELD_ORDER = "client"

#Creating drink field name constants
ID_FIELD_DRINK = "id"
PRICE_FIELD_DRINK = "price"
NAME_FIELD_DRINK = "name"
DESCRIPTION_FIELD_DRINK = "description"

#Creating orderDrink field name constants
QTY_FIELD_ORDERED_DRINK = "qty"
DRINK_FIELD_ORDERED_DRINK = "drink"
ORDERS_FIELD_ORDERED_DRINK = "orders"

class DatabaseInterface:
    #DatabaseInterface constructor
    def __init__(self,dbname,user,host,password):

        #Connection to the database
        self.engine = create_engine('postgresql://{0}:{1}@{2}:5432/{3}'.format(user,password,host,dbname),
        isolation_level="SERIALIZABLE")

        #Getting metadata
        self.metadata = MetaData()

        #Creation of tables
        self.dbs = dict()

        #Table creation
        self.initializeTables()

    #Connects to the database
    def connect(self):
        try:
            self.connection = self.engine.connect()
        except:
            raise DatabaseException("Couldn't not connect to database")

    #Disconnect from the database
    def disconnect(self):
        self.connection.close()

    #Assisn the table witht the barcode to the client. The client gets a token allowing him to passes order.
    #This token is returned by the function
    def AcquireTable(self,barcode):

        returnedToken = None
        transaction=self.connection.begin()

        try:

            #Check is the barcode exist
            uniqueBarCode = self.connection.execute(
                self.dbs[EMPLACEMENT_TABLE].select().
                    where(self.dbs[EMPLACEMENT_TABLE].c[ID_FIELD_EMPLACEMENT] == barcode)
            ).first()

            if uniqueBarCode is None:
                raise DatabaseException('The emplacement does not exist')

            #Check if the table is Free
            tableFree = self.connection.execute(
                self.dbs[CLIENT_EMPLACEMENT_TABLE].select().
                    where(self.dbs[CLIENT_EMPLACEMENT_TABLE].c[EMPLACEMENT_FIELD_CLIENT_EMPLACEMENT] == barcode)
            ).first()

            if tableFree is not None:
                raise DatabaseException('The table is not free')

            #Creating client
            clientCreation = self.connection.execute(
                self.dbs[CLIENT_TABLE].insert().values(
                )
            )

            clientToken = clientCreation.inserted_primary_key[0]

            #Assigning the table to the client
            clientTableAssignation = self.connection.execute(
                self.dbs[CLIENT_EMPLACEMENT_TABLE].insert().values(
                {
                EMPLACEMENT_FIELD_CLIENT_EMPLACEMENT:barcode,
                CLIENT_FIELD_CLIENT_EMPLACEMENT:clientToken
                }
                )
            )

            returnedToken = clientToken
            #If no errors we commit the transaction
            transaction.commit()

        #If we caught an unexpected exception we rollback and rais the exception
        except Exception as e:
            transaction.rollback()
            raise DatabaseException(str(e))

        #In either case we close the connection
        finally:
            transaction.close()

        return returnedToken

    #Orders a list of (drink,quantoty) for the client with the token
    def OrderDrinks(self,token,orderList):
        #Checking the token given is valid
        if not self.tokenIsValid(token):
            raise DatabaseException("The token is not valid")
        #Checking the token is assigned to a table
        if not self.tableIsOccupied(token):
            raise DatabaseException("The table is not occupied")


        #Creating an order and getting it's id(no transaction needed here because no race condition)
        orderInsertion = self.connection.execute(
            self.dbs[ORDERS_TABLE].insert().values(
                {
                CLIENT_FIELD_ORDER:token,
                TIME_FIELD_ORDER:datetime.now()
                }
            )
        )

        orderId = orderInsertion.inserted_primary_key[0]

        #For each drink in the list we try to order
        for drinkName,quantity in orderList:

            #We can't order a negative number of drinks
            if quantity < 1:
                print("Drink with with id "+ str(drinkId)+" has an invalid quantity")
            else:

                #Check if the drinkId is valid
                drinkId = self.drinkIsValid(drinkName)
                if drinkId is not None:

                    #Add the drink to the order
                    drinkInsertion = self.connection.execute(
                        self.dbs[ORDERED_DRINK_TABLE].insert().values(
                            {
                            QTY_FIELD_ORDERED_DRINK:quantity,
                            DRINK_FIELD_ORDERED_DRINK:drinkId,
                            ORDERS_FIELD_ORDERED_DRINK: orderId
                            }
                        )
                    )
                else:
                    print("The drink {0} does not exist".format(drinkName))

        return orderId


    def IssueTicket(self,token):
        #Checking the token given is valid
        if not self.tokenIsValid(token):
            raise DatabaseException("The token is not valid")

        #Checking the token is assigned to a table
        if not self.tableIsOccupied(token):
            raise DatabaseException("The table is not occupied")

        #Getting the list of orederd drinks
        orderedDrinkList = self.connection.execute(
            select([self.dbs[DRINK_TABLE].c[NAME_FIELD_DRINK],
                    self.dbs[ORDERED_DRINK_TABLE].c[QTY_FIELD_ORDERED_DRINK],
                    self.dbs[DRINK_TABLE].c[PRICE_FIELD_DRINK]]).
            select_from(self.dbs[ORDERS_TABLE].
                    join(self.dbs[ORDERED_DRINK_TABLE]).
                    join(self.dbs[DRINK_TABLE])).
        where(self.dbs[ORDERS_TABLE].c[CLIENT_FIELD_ORDER] == token)).fetchall()

        #Computing the total price of the ordered drinks
        totalPrice = 0
        for name,quantity,price in orderedDrinkList:
            totalPrice += (quantity*price)

        return orderedDrinkList, totalPrice

    def PayTable(self,token,amountPaid):

        #Checking the token given is valid
        if not self.tokenIsValid(token):
            raise DatabaseException("The token is not valid")

        #Checking the token is assigned to a table
        if not self.tableIsOccupied(token):
            raise DatabaseException("The table is not occupied")

        #Starting the transaction
        transaction=self.connection.begin()
        try:
            #Reusing the Issue tocket methode to get the  total amount to pay(pre condition is ensure in the issueticket  method)
            orderedDrinks, priceToPay = self.IssueTicket(token)

            if amountPaid < priceToPay:
                raise DatabaseException("The amount paid is lower than the amount due")
            else:
                #Create payment
                paymentCreation = self.connection.execute(
                    self.dbs[PAYMENT_TABLE].insert().values(
                        {
                        AMOUNT_FIELD_PAYMENT:amountPaid,
                        CLIENT_FIELD_PAYMENT:token
                        }
                    )
                )
                #Delete the client
                self.connection.execute(
                    self.dbs[CLIENT_EMPLACEMENT_TABLE].delete().
                    where(
                        self.dbs[CLIENT_EMPLACEMENT_TABLE].c[CLIENT_FIELD_CLIENT_EMPLACEMENT] == token
                    )
                )

            transaction.commit()
        except Exception as e:
            transaction.rollback()
            print(e)
        finally:
            transaction.close()




    def drinkIsValid(self,drinkName):
        
        validDrink = self.connection.execute(
            self.dbs[DRINK_TABLE].select().
            where(self.dbs[DRINK_TABLE].c[NAME_FIELD_DRINK] == drinkName)
        ).first()

        #if no drink was found it does not exist, else we return the drink id
        if validDrink is None:
            return None
        else:
            return validDrink[0]

    def tokenIsValid(self,token):

        #If a client exist with the token in the database(If a client exist the table assign is valid too)
        validClient = self.connection.execute(
            self.dbs[CLIENT_TABLE].select().
                where(self.dbs[CLIENT_TABLE].c[ID_FIELD_CLIENT] == token)
        ).first()

        #If the query return smth the token is valid
        if validClient is None:
            return False
        else:
            return True

    def tableIsOccupied(self,token):

        #If there is an entry in the client_emplacement with the token it mean the table is occupied
        occupiedTable = self.connection.execute(
            self.dbs[CLIENT_EMPLACEMENT_TABLE].select().
                where(self.dbs[CLIENT_EMPLACEMENT_TABLE].c[CLIENT_FIELD_CLIENT_EMPLACEMENT] == token)
        ).first()

        #If the query returns smth the table is in user
        if occupiedTable is None:
            return False
        else:
            return True

    def initializeTables(self):

        #Creating table emplacement
        self.dbs[EMPLACEMENT_TABLE] = Table(EMPLACEMENT_TABLE,self.metadata, \
            Column(ID_FIELD_CLIENT,Integer,primary_key=True)\
            )

        #Creating table client
        self.dbs[CLIENT_TABLE] = Table(CLIENT_TABLE,self.metadata, \
            Column(ID_FIELD_CLIENT,Integer,primary_key=True), \
            )

        #Creating table client_emplacement
        self.dbs[CLIENT_EMPLACEMENT_TABLE] = Table(CLIENT_EMPLACEMENT_TABLE,self.metadata,\
            Column(CLIENT_FIELD_CLIENT_EMPLACEMENT,ForeignKey("{0}.{1}".format(CLIENT_TABLE,ID_FIELD_CLIENT)),primary_key=True),
            Column(EMPLACEMENT_FIELD_CLIENT_EMPLACEMENT,ForeignKey("{0}.{1}".format(EMPLACEMENT_TABLE,ID_FIELD_EMPLACEMENT)))
        )

        #Creating table payment
        self.dbs[PAYMENT_TABLE] = Table(PAYMENT_TABLE,self.metadata, \
            Column(ID_FIELD_PAYMENT,Integer,primary_key=True),\
            Column(AMOUNT_FIELD_PAYMENT,Integer),\
            Column(CLIENT_FIELD_PAYMENT,ForeignKey("{0}.{1}".format(CLIENT_TABLE,ID_FIELD_CLIENT)))\
            )

        #Creating table order
        self.dbs[ORDERS_TABLE] = Table(ORDERS_TABLE,self.metadata,\
            Column(ID_FIELD_ORDER,Integer,primary_key=True),\
            Column(TIME_FIELD_ORDER,Date),\
            Column(CLIENT_FIELD_ORDER,ForeignKey("{0}.{1}".format(CLIENT_TABLE,ID_FIELD_CLIENT)))\
            )

        #Creating table drink
        self.dbs[DRINK_TABLE] = Table(DRINK_TABLE,self.metadata,\
            Column(ID_FIELD_DRINK,Integer,primary_key=True),\
            Column(PRICE_FIELD_DRINK,Integer),\
            Column(NAME_FIELD_DRINK,String),\
            Column(DESCRIPTION_FIELD_DRINK,String)\
            )

        #Creating table ordered_drink
        self.dbs[ORDERED_DRINK_TABLE] = Table(ORDERED_DRINK_TABLE,self.metadata,\
            Column(QTY_FIELD_ORDERED_DRINK,Integer),\
            Column(DRINK_FIELD_ORDERED_DRINK,ForeignKey("{0}.{1}".format(DRINK_TABLE,ID_FIELD_DRINK))),\
            Column(ORDERS_TABLE,ForeignKey("{0}.{1}".format(ORDERS_TABLE,ID_FIELD_ORDER)))\
            )
