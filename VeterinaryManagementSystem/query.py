import pymysql

def execute_query_to_string(connection, query):
    """
    Executes a given SQL query and returns the output as a formatted string.
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute(query)
            results = cursor.fetchall()
            
            if results:
                # Format the results into a string
                output = []
                headers = results[0].keys()
                header_line = ' | '.join(headers)
                separator = '-' * len(header_line)
                
                # Add headers
                output.append(header_line)
                output.append(separator)
                
                # Add each row
                for row in results:
                    row_line = ' | '.join(str(value) for value in row.values())
                    output.append(row_line)
                
                return '\n'.join(output)
            else:
                return "No results found for the query."
    
    except pymysql.MySQLError as e:
        return f"Error executing query: {e}"


def add_appointment(connection):
    """
    Adds a new appointment to the APPOINTMENT table.
    """
    try:
        date_time = input("Enter the date and time of the appointment (YYYY-MM-DD HH:MM:SS): ")
        appointment_type = input("Enter the appointment type (e.g., Vaccination,Emergency,Check-up,Surgery,Consultation,Follow-up): ")
        status = input("Enter the status (e.g., Scheduled, Completed, Cancelled,In Progress,Pending): ")
        vet_id = int(input("Enter the Veterinarian ID: "))
        animal_id = int(input("Enter the Animal ID: "))

        query = """
        INSERT INTO APPOINTMENT (Date_Time, Appointment_Type, Status, Vet_ID, Animal_ID)
        VALUES (%s, %s, %s, %s, %s);
        """
        with connection.cursor() as cursor:
            cursor.execute(query, (date_time, appointment_type, status, vet_id, animal_id))
        connection.commit()
        print("Appointment added successfully!")
    except pymysql.MySQLError as e:
        
        print(f"Error adding appointment: {e}")
        result_string = execute_query_to_string(connection, query)
        print(result_string)
    except ValueError:
        print("Invalid input! Please ensure IDs are integers and date/time is correctly formatted.")


def add_animal(connection):
    """
    Adds a new animal to the ANIMAL table.
    """
    try:
        name = input("Enter the animal's name: ")
        species = input("Enter the species (e.g., Dog, Cat): ")
        breed = input("Enter the breed: ")
        gender = input("Enter the gender (M/F): ")
        dob = input("Enter the date of birth (YYYY-MM-DD): ")
        weight = float(input("Enter the weight (in kg): "))
        height = float(input("Enter the height (in cm): "))
        owner_id = int(input("Enter the Owner ID: "))

        query = """
        INSERT INTO ANIMAL (Name, Species, Breed, Gender, DOB, Weight, Height, Owner_ID)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s);
        """
        with connection.cursor() as cursor:
            cursor.execute(query, (name, species, breed, gender, dob, weight, height, owner_id))
        connection.commit()
        print("Animal added successfully!")
    except pymysql.MySQLError as e:
        print(f"Error adding animal: {e}")
        result_string = execute_query_to_string(connection, query)
        print(result_string)
    except ValueError:
        print("Invalid input! Please ensure numerical fields are entered correctly.")


def get_dog_diseases(connection):
    """
    Retrieves and displays all diseases affecting dogs from the DISEASE table.
    """
    try:
        query = """
        SELECT Disease_Name, Symptoms, Typical_Duration 
        FROM DISEASE 
        WHERE Species_Affected LIKE '%Dog%';
        """
        with connection.cursor() as cursor:
            cursor.execute(query)
            results = cursor.fetchall()
        
       
        if results:
            # Print headers with lines below
            print("\nDiseases Affecting Dogs:")
            print("-" * 100)
            print(f"{'Disease Name':<35} | {'Symptoms':<50} | {'Typical Duration':<10}")
            print("-" * 100)
            
            # Print each row in the results with lines between columns and rows
            for row in results:
                print(f"{row['Disease_Name']:<35} | {row['Symptoms']:<50} | {row['Typical_Duration']:<10}")
                # print("-" * 100)  # Line after each row
        else:
            print("No diseases found affecting dogs.")
    except pymysql.MySQLError as e:
        print(f"Error retrieving diseases: {e}")
        result_string = execute_query_to_string(connection, query)
        print(result_string)

def get_billing_and_appointment(connection):
    """
    Retrieves billing details along with appointment information for a specific owner.
    """
    try:
        owner_id = int(input("Enter the Owner ID to retrieve billing and appointment details: "))
        
        query = """
        SELECT B.Date_of_Payment, B.Amount_Paid, A.Date_Time, A.Appointment_Type
        FROM BILLING B
        JOIN APPOINTMENT A ON B.Appointment_ID = A.Appointment_ID
        WHERE B.Owner_ID = %s;
        """
        with connection.cursor() as cursor:
            cursor.execute(query, (owner_id,))
            results = cursor.fetchall()
        
       
        if results:
            # Print headers with lines below
            print("\nBilling and Appointment Information:")
            print("-" * 100)
            print(f"{'Date of Payment':<20} | {'Amount Paid':<15} | {'Appointment Date & Time':<30} | {'Appointment Type':<20}")
            print("-" * 100)

         
            
                
            # Print each row in the results with lines between columns and rows
            for row in results:
                   date_of_payment = str(row['Date_of_Payment'])
                #    print(date_of_payment)
                   amount_paid = f"{row['Amount_Paid']:.2f}"  # Format amount to 2 decimal places
                   appointment_datetime = str(row['Date_Time'])
                   appointment_type = str(row['Appointment_Type'])
                   print(f"{date_of_payment:<20} | {amount_paid:<15} | {appointment_datetime:<30} | {appointment_type:<20}")
                #    print(f"{row['Date_of_Payment']:<20} | {row['Amount_Paid']:<14} | {row['Date_Time']:<30} | {row['Appointment_Type']:<20}")
                # print("-" * 100)  # Line after each row
        else:
            print("No billing and appointment information found for this owner.")
    except pymysql.MySQLError as e:
        print(f"Error retrieving billing and appointment information: {e}")
        result_string = execute_query_to_string(connection, query)
        print(result_string)
    except ValueError:
        print("Invalid input! Please ensure the Owner ID is an integer.")

def get_vet_and_staff_contact(connection):
    """
    Retrieves the contact details (name and email) of all veterinarians and staff.
    """
    try:
        query = """
        SELECT V.First_Name, V.Last_Name, V.Contact_Info AS PhoneNumber
        FROM VET_CONTACT V
        UNION
        SELECT SC.First_Name, SC.Last_Name, SC.Contact_Info AS PhoneNumber 
        FROM STAFF_CONTACT SC;
        """
        with connection.cursor() as cursor:
            cursor.execute(query)
            results = cursor.fetchall()
        
       
        if results:
            # Print headers with lines below
            print("\nVeterinarian and Staff Contact Information:")
            print("-" * 80)
            print(f"{'First Name':<25} | {'Last Name':<25} | {'Phone Number':<20}")
            print("-" * 80)
            
            # Print each row in the results with lines between columns and rows
            for row in results:
                print(f"{row['First_Name']:<25} | {row['Last_Name']:<25} | {row['PhoneNumber']:<20}")
                print("-" * 80)  # Line after each row
        else:
            print("No contact information found for veterinarians and staff.")
    except pymysql.MySQLError as e:
        print(f"Error retrieving contact information: {e}")
        result_string = execute_query_to_string(connection, query)
        print(result_string)

def get_total_revenue(connection):
    """
    Retrieves the total revenue generated from appointments by summing the Amount_Paid in the BILLING table.
    """
    try:
        query = """
        SELECT SUM(Amount_Paid) AS Total_Revenue 
        FROM BILLING;
        """
        with connection.cursor() as cursor:
            cursor.execute(query)
            result = cursor.fetchone()
        
        if result:
            total_revenue = result['Total_Revenue']
            print("\nTotal Revenue Generated from Appointments:\n")
            # print("-" * 50)
            print(f"Total Revenue: {total_revenue:.2f}")
            print("-" * 50)
        else:
            print("No revenue data found.")
    except pymysql.MySQLError as e:
        print(f"Error retrieving total revenue: {e}")
        result_string = execute_query_to_string(connection, query)
        print(result_string)

def update_appointment_status(connection):
    """
    Updates the status of an appointment to 'Completed' after treatment.
    """
    try:
        appointment_id = int(input("Enter the Appointment ID to mark as completed: "))
        
        with connection.cursor() as cursor:
            # Check the current status of the appointment
            cursor.execute("SELECT Status FROM APPOINTMENT WHERE Appointment_ID = %s", (appointment_id,))
            result = cursor.fetchone()
            
            if not result:
                print(f"Error: No appointment found with ID {appointment_id}.")
            elif result['Status'] == 'Completed':
                print(f"Appointment {appointment_id} is already marked as 'Completed'. No modification needed.")
            else:
                # Proceed with updating the status
                update_query = """
                UPDATE APPOINTMENT
                SET Status = 'Completed'
                WHERE Appointment_ID = %s;
                """
                cursor.execute(update_query, (appointment_id,))
                connection.commit()
                
                if cursor.rowcount > 0:
                    print(f"Appointment {appointment_id} has been marked as 'Completed'.")
                    # Display the updated record
                    cursor.execute("SELECT * FROM APPOINTMENT WHERE Appointment_ID = %s", (appointment_id,))
                    updated_result = cursor.fetchone()
                    print("\nUpdated Appointment Record:")
                    headers = updated_result.keys()
                    header_line = ' | '.join(headers)
                    separator = '-' * len(header_line)
                    print(header_line)
                    print(separator)
                    row_line = ' | '.join(str(value) for value in updated_result.values())
                    print(row_line)
                else:
                    print("Failed to update the appointment.")
                    
    except pymysql.MySQLError as e:
        print(f"SQL Error: {e.args[1]} (Error Code: {e.args[0]})")
    except ValueError:
        print("Invalid input! Please ensure the Appointment ID is an integer.")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")

def update_medicine_stock_after_restock(connection):
    """
    Increases the stock of a specific medicine after restocking.
    """
    try:
        medicine_name = input("Enter the medicine name to restock: ")
        restock_amount = int(input("Enter the amount to add to the stock: "))
        
        with connection.cursor() as cursor:
            # Check if the medicine exists in the inventory
            cursor.execute("SELECT Medicine_Name, Current_Stock FROM MEDICINE_INVENTORY WHERE Medicine_Name = %s", (medicine_name,))
            result = cursor.fetchone()
            
            if not result:
                print(f"Error: Medicine '{medicine_name}' does not exist in the inventory.")
            else:
                # Proceed with updating the stock
                current_stock = result['Current_Stock']
                cursor.execute(
                    "UPDATE MEDICINE_INVENTORY SET Current_Stock = Current_Stock + %s WHERE Medicine_Name = %s",
                    (restock_amount, medicine_name)
                )
                connection.commit()
                
                if cursor.rowcount > 0:
                    print(f"Stock of '{medicine_name}' has been increased by {restock_amount}.")
                    # Display the updated stock level
                    cursor.execute("SELECT * FROM MEDICINE_INVENTORY WHERE Medicine_Name = %s", (medicine_name,))
                    updated_result = cursor.fetchone()
                    print("\nUpdated Medicine Record:")
                    headers = updated_result.keys()
                    header_line = ' | '.join(headers)
                    separator = '-' * len(header_line)
                    print(header_line)
                    print(separator)
                    row_line = ' | '.join(str(value) for value in updated_result.values())
                    print(row_line)
                else:
                    print("Failed to update the medicine stock.")
                    
    except pymysql.MySQLError as e:
        print(f"SQL Error: {e.args[1]} (Error Code: {e.args[0]})")
    except ValueError:
        print("Invalid input! Please ensure the amount is a valid integer.")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")


def update_medicine_stock_after_treatment(connection):
    """
    Reduces the stock of a specific medicine after it is used during treatment.
    """
    try:
        medicine_id = int(input("Enter the Medicine ID used during treatment: "))
        used_amount = int(input("Enter the amount of medicine used: "))
        
        with connection.cursor() as cursor:
            # Check if the medicine exists in the inventory
            cursor.execute("SELECT Medicine_ID, Current_Stock FROM MEDICINE_INVENTORY WHERE Medicine_ID = %s", (medicine_id,))
            result = cursor.fetchone()
            
            if not result:
                print(f"Error: Medicine with ID {medicine_id} does not exist in the inventory.")
            else:
                current_stock = result['Current_Stock']
                if current_stock < used_amount:
                    print(f"Error: Not enough stock available. Current stock: {current_stock}, requested: {used_amount}.")
                else:
                    # Proceed with reducing the stock
                    cursor.execute(
                        "UPDATE MEDICINE_INVENTORY SET Current_Stock = Current_Stock - %s WHERE Medicine_ID = %s",
                        (used_amount, medicine_id)
                    )
                    connection.commit()
                    
                    if cursor.rowcount > 0:
                        print(f"Stock of medicine with ID {medicine_id} has been reduced by {used_amount}.")
                        # Display the updated stock level
                        cursor.execute("SELECT * FROM MEDICINE_INVENTORY WHERE Medicine_ID = %s", (medicine_id,))
                        updated_result = cursor.fetchone()
                        print("\nUpdated Medicine Record:")
                        headers = updated_result.keys()
                        header_line = ' | '.join(headers)
                        separator = '-' * len(header_line)
                        print(header_line)
                        print(separator)
                        row_line = ' | '.join(str(value) for value in updated_result.values())
                        print(row_line)
                    else:
                        print("Failed to update the medicine stock.")
    
    except pymysql.MySQLError as e:
        print(f"SQL Error: {e.args[1]} (Error Code: {e.args[0]})")
    except ValueError:
        print("Invalid input! Please ensure the Medicine ID and amount are valid integers.")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")


def execute_query_with_output(connection, query, params=None, fetch_output=False):
    """
    Executes an SQL query with optional parameters and provides detailed output and error handling.
    
    Parameters:
    - connection: The database connection object.
    - query: The SQL query to be executed.
    - params: Optional tuple of parameters for parameterized queries.
    - fetch_output: Boolean indicating whether to fetch and return query results.
    
    Returns:
    - Success message or detailed error output.
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute(query, params)
            connection.commit()

            if fetch_output:
                results = cursor.fetchall()
                if results:
                    headers = results[0].keys()
                    output = []
                    output.append(' | '.join(headers))
                    output.append('-' * 80)
                    for row in results:
                        output.append(' | '.join(str(value) for value in row.values()))
                    return '\n'.join(output)
                else:
                    return "Query executed successfully but no results found."

            return "Query executed successfully."

    except pymysql.IntegrityError as e:
        error_message = (
            f"Integrity Error: {e.args[1]} (Error Code: {e.args[0]})\n"
            f"Query: {query}\n"
            f"Parameters: {params}"
        )
        return error_message

    except pymysql.MySQLError as e:
        error_message = (
            f"SQL Error: {e.args[1]} (Error Code: {e.args[0]})\n"
            f"Query: {query}\n"
            f"Parameters: {params}"
        )
        return error_message


def assign_mentor_to_veterinarian(connection):
    """
    Assigns a mentor (senior veterinarian) to a junior veterinarian and prints detailed error messages.
    """
    try:
        junior_vet_id = int(input("Enter the Vet ID of the junior veterinarian: "))
        mentor_vet_id = int(input("Enter the Vet ID of the mentor (senior veterinarian): "))

        update_query = """
        UPDATE VETERINARIAN
        SET Super_Vet_ID = %s
        WHERE Vet_ID = %s;
        """

        with connection.cursor() as cursor:
            try:
                cursor.execute(update_query, (mentor_vet_id, junior_vet_id))
                connection.commit()

                if cursor.rowcount == 0:
                    print(f"No records updated. Either Vet ID {junior_vet_id} does not exist or is invalid.")
                else:
                    print("Query executed successfully.")
                    # Display the updated record for confirmation
                    cursor.execute("SELECT Vet_ID, Super_Vet_ID FROM VETERINARIAN WHERE Vet_ID = %s", (junior_vet_id,))
                    result = cursor.fetchone()
                    if result:
                        print(f"\nUpdated Veterinarian Record: Vet_ID: {result['Vet_ID']}, Super_Vet_ID: {result['Super_Vet_ID']}")
                    else:
                        print("Unable to retrieve updated record.")
                        
            except pymysql.IntegrityError as e:
                connection.rollback()
                print(f"Integrity Error: {e.args[1]} (Error Code: {e.args[0]})")
            except pymysql.MySQLError as e:
                connection.rollback()
                print(f"SQL Error: {e.args[1]} (Error Code: {e.args[0]})")

    except ValueError:
        print("Invalid input! Please ensure Vet IDs are integers.")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")



def remove_expired_appointments(connection):
    """
    Removes appointments that are older than or exactly one year from the current date.
    """
    try:
        # Check if there are any expired appointments before deleting them
        check_query = """
        SELECT Appointment_ID, Date_Time FROM APPOINTMENT
        WHERE Date_Time <= NOW() - INTERVAL 1 YEAR;
        """
        
        with connection.cursor() as cursor:
            cursor.execute(check_query)
            expired_appointments = cursor.fetchall()
            
            if expired_appointments:
                print("Expired appointments found:")
                # Print the expired appointments
                headers = ['Appointment_ID', 'Date_Time']
                header_line = ' | '.join(headers)
                separator = '-' * len(header_line)
                print(header_line)
                print(separator)
                
                # Print each expired appointment
                for appointment in expired_appointments:
                    print(f"{appointment['Appointment_ID']} | {appointment['Date_Time']}")
                
                # Proceed to remove expired appointments
                delete_query = """
                DELETE FROM APPOINTMENT
                WHERE Date_Time <= NOW() - INTERVAL 1 YEAR;
                """
                cursor.execute(delete_query)
                connection.commit()
                
                print(f"\n{len(expired_appointments)} expired appointments have been removed.")
            else:
                print("No expired appointments to remove.")
    
    except pymysql.MySQLError as e:
        print(f"Error removing expired appointments: {e}")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")


# Function to display the menu and prompt for user input
def display_operations():
    """
    Display the CLI menu options.
    """
    print("\nVeterinary Management System")
    print("1. Add Appointment")
    print("2. Add Animal")
    print("3. Get Diseases Affecting Dogs")
    print("4. Get Billing and Appointment Information")
    print("5. Get Veterinarian and Staff Contact Details")
    print("6. Get Total Revenue Generated from Appointments")
    print("7. Update Appointment Status")
    print("8. Update Medicine Stock After Restocking")
    print("9. Update Medicine Stock After Treatment")
    print("10. Assign Mentor to Junior Veterinarian")
    print("11. Remove Expired Appointments")
    print("12. Exit")


def execute_sql_file(connection, file_path):
    """
    Reads and executes SQL commands from a given file.
    """
    with open(file_path, 'r') as file:
        sql_commands = file.read()
    
    # Split commands by semicolon (;) to handle multiple statements
    sql_commands = sql_commands.split(';')
    cursor = connection.cursor()

    try:
        for command in sql_commands:
            if command.strip():  # Skip empty lines
                cursor.execute(command)
        connection.commit()
        print(f"Executed {file_path} successfully.")
    except pymysql.MySQLError as e:
        print(f"Error executing {file_path}: {e}")
        connection.rollback()
    finally:
        cursor.close()

        
# Command-Line Interface (CLI)
def main():
    # connection = get_db_connection()
    host = 'localhost'
    user = input("Enter your MySQL username: ")
    password = input("Enter your MySQL password: ")
    database = 'VeterinaryClinic'

    # Paths to SQL files
    create_file = 'create.sql'  # Path to the SQL file that creates the schema
    concs_file = 'populate.sql'    # Path to the SQL file that populates the database

    try:
        # Connect to MySQL server
        connection = pymysql.connect(
            host=host,
            user=user,
            password=password,
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
        print("Connected to the MySQL server successfully.")

        execute_sql_file(connection, create_file)

        # Use the newly created database
        with connection.cursor() as cursor:
            cursor.execute(f"USE {database}")

        # Execute the population script
        execute_sql_file(connection, concs_file)
    except pymysql.MySQLError as e:
        print(f"Error connecting to the database: {e}")
        exit(1)

    while True:

        display_operations()
        # print("11. Remove Expired Medicines")

        choice = input("Enter your choice: ")

        if choice == "1":
            add_appointment(connection)
        elif choice == "2":
            add_animal(connection)
        elif choice == "3":
            get_dog_diseases(connection)
        elif choice == "4":
            get_billing_and_appointment(connection)
        elif choice == "5":
            get_vet_and_staff_contact(connection)
        elif choice == "6":
            get_total_revenue(connection)       
        elif choice == "7" :
            update_appointment_status(connection)
        elif choice == "8":
            update_medicine_stock_after_restock(connection)
        elif choice == "9":
            update_medicine_stock_after_treatment(connection)
        elif choice == "10":
            assign_mentor_to_veterinarian(connection)
        elif choice == "11":
            remove_expired_appointments(connection)

        elif choice == "12":
            print("...Exiting...")
            connection.close()
            break
        else:
            print("----------------Invalid choice! Please try again.---------------------")



if __name__ == "__main__":
    main()
