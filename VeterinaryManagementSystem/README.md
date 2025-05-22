# **Veterinary Management System**

**Team 10**

Members: Harshika, Rithvika, Vaishnavi, Vishakha

## **Overview**

The Veterinary Management System is a Python-based Command-Line Interface (CLI) application designed to manage operations for a veterinary clinic. It connects to a MySQL database to handle tasks such as managing appointments, animals, billing, inventory, and generating summary reports. The application ensures smooth and efficient data handling while providing detailed error messages for troubleshooting.

**How to Run**

1. Run the Python script to set up the database VeterinaryClinic.

python query.py

1. Enter your MySQL username and password when prompted.
2. Use the interactive menu to navigate through various operations.

**Commands and Descriptions**

Below is a detailed list of the commands available in our system:

**1\. Add Appointment**

- **Command**: Enter 1 in the menu.
- **Description**: Adds a new appointment to the APPOINTMENT table.
- **Inputs**:
  - **Date and Time**: Format YYYY-MM-DD HH:MM:SS.
  - **Appointment Type**: Type of appointment (e.g., Vaccination, Emergency).
  - **Status**: Appointment status (e.g., Scheduled, Completed).
  - **Vet ID**: Veterinarian ID (integer).
  - **Animal ID**: Animal ID (integer).
- **Output**: Prints a success message or an error if input is invalid or there is a database issue.

**2\. Add Animal**

- **Command**: Enter 2 in the menu.
- **Description**: Adds a new animal to the ANIMAL table.
- **Inputs**:
  - **Name**: Animal's name.
  - **Species**: Species (e.g., Dog, Cat).
  - **Breed**: Breed of the animal.
  - **Gender**: Gender (M/F).
  - **Date of Birth**: Format YYYY-MM-DD.
  - **Weight**: Animal's weight (float).
  - **Height**: Animal's height (float).
  - **Owner ID**: Owner's ID (integer).
- **Output**: Prints a success message or an error if input is invalid or there is a database issue.

**3\. Get Diseases Affecting Dogs**

- **Command**: Enter 3 in the menu.
- **Description**: Retrieves all diseases affecting dogs from the DISEASE table.
- **Output**: Displays disease names, symptoms, and typical durations in a tabular format. If no diseases are found, displays a "No results" message.

**4\. Get Billing and Appointment Information**

- **Command**: Enter 4 in the menu.
- **Description**: Retrieves billing and appointment details for a specific owner.
- **Inputs**:
  - **Owner ID**: The ID of the owner (integer).
- **Output**: Displays details including payment date, amount paid, appointment type, and date. If no data is found, displays a "No results" message.

**5\. Get Veterinarian and Staff Contact Details**

- **Command**: Enter 5 in the menu.
- **Description**: Fetches contact details for all veterinarians and staff.
- **Output**: Displays names and phone numbers of veterinarians and staff in a formatted table. If no contacts are found, displays a "No results" message.

**6\. Get Total Revenue Generated from Appointments**

- **Command**: Enter 6 in the menu.
- **Description**: Calculates the total revenue from the BILLING table.
- **Output**: Displays the total revenue. If no data is found, displays a message indicating no revenue data.

**7\. Update Appointment Status**

- **Command**: Enter 7 in the menu.
- **Description**: Updates the status of an appointment to "Completed".
- **Inputs**:
  - **Appointment ID**: ID of the appointment (integer).
- **Output**: Displays a success message if the status is updated or an error if the input is invalid.

**8\. Update Medicine Stock After Restocking**

- **Command**: Enter 8 in the menu.
- **Description**: Increases the stock of a specific medicine in the MEDICINE_INVENTORY table.
- **Inputs**:
  - **Medicine Name**: Name of the medicine.
  - **Restock Amount**: Quantity to add (integer).
- **Output**: Displays a success message or an error if input is invalid.

**9\. Update Medicine Stock After Treatment**

- **Command**: Enter 9 in the menu.
- **Description**: Reduces the stock of a specific medicine in the MEDICINE_INVENTORY table.
- **Inputs**:
  - **Medicine ID**: ID of the medicine (integer).
  - **Used Amount**: Quantity used (integer).
- **Output**: Displays a success message or an error if input is invalid.

**10\. Assign Mentor to Junior Veterinarian**

- **Command**: Enter 10 in the menu.
- **Description**: Assigns a mentor (senior veterinarian) to a junior veterinarian.
- **Inputs**:
  - **Junior Vet ID**: ID of the junior veterinarian (integer).
  - **Mentor Vet ID**: ID of the mentor (integer).
- **Output**: Displays a success message or an error if input is invalid.

**11\. Remove Expired Appointments**

- **Command**: Enter 11 in the menu.
- **Description**: Deletes all appointments older than or exactly one year.
- **Output**: Displays a success message or an error if there are issues during deletion.

**12\. Exit**

- **Command**: Enter 12 in the menu.
- **Description**: Exits the application and terminates the database connection.

**Error Handling**

The system provides clear error messages for:

1. **Invalid Inputs**: Displays appropriate prompts to correct input formatting.
2. **Database Errors**: Provides detailed error messages for troubleshooting (e.g., connection issues, query execution failures).

**Additionally,**

- **execute_query_to_string**: This function formats query results into a readable string for enhanced CLI presentation.
- **Change made to attribute in SUPPLIER**: The H_No attribute was renamed to Facility_No in the final implementation.