#FoodLink Society

#Overview:
FoodLink Society is a Flutter application designed to connect food donors, volunteers, and store owners in a community-driven food distribution network. The app facilitates role-based access for admins, volunteers, and store owners, using Firebase for backend services including authentication and data storage.

#Features:
- Role-Based Access: Supports multiple user roles including Admin, Volunteer, and Store Owner.
- Authentication: Secure login and authentication via Firebase.
- Dashboards: Customized dashboards for each user role with relevant functionalities.
- Real-Time Database: Uses Cloud Firestore for real-time data synchronization.

#Getting Started:

#Prerequisites:
- Flutter SDK (^3.9.2)
- Dart SDK (^3.9.2)
- Firebase project setup with Firestore enabled

#Installation:
1. Clone the repository:
   git clone https://gitlab.com/twu8/2025-3-cmpt385-07.git

2. Install dependencies:
   flutter pub get

3. Run the app:
   flutter run

#Usage:

#User Guide Overview:
FoodLink is a multi-role app to manage food donations and deliveries. Users can register and log in as a Volunteer, Admin, or Store Owner to perform role-specific actions.

#Volunteer Workflow:
- Launch the app and select the Volunteer role. 
- Register through by creating an account. If you already have an account but forgot password then you can request a new password.
- Add items to the database. Multiple entries can be created.
- Delete any incorrect entries before submission.
- Add additional notes to entries if needed.
- Click Submit to save the information to Firestore.
- Contact Store feature displays contact information and address of the stores. The call button redirects you to your phone’s dialer to place the call.
- Stores can be searched using the search box by putting in the name or phone number of the store.
- There is a guide at the top of the dashboard for navigation. 

#Admin Workflow:
- Log in using admin credentials to access the homepage. Use forget password to have a new password.
- The homepage displays the entries made by the volunteers. 
- Widgets show:
    - Number of unverified entries
    - Number of stores with no entry today
- Verify new delivery entries by clicking the check mark.
- Delete incorrect entries using the delete option.
- Entries can also be filtered using either the store name, volunteer name, and date on the search box.
- Add new stores using the store icon and generate a unique code for them. 
- Sidebar has a reports and analytics feature where real time data can be visuallized and a history of entries can be viewed. 
- Admin can either download a csv file either locally or sent them over email. 
- For testing the email feature you could replace your email address with "shubham.verma@mytwu.ca" in reports.dart file. 
- Store Database feature displays all the partner stores registered with the app and their contact details. 
- Search box also helps looking for a particular store by using either the name or code of the store.                                                        
- Logout using the button at the top.


#Store Owner Workflow:
- Login using a unique code provided to the store. (For testing this, you can use code: "8VUAHN". More codes can be accessed through our database) 
- The dashboard displays two widgets that shows total weight of food donated by the store and the total number of boxes donated.
- Real time donation data can be visuallized. 
- Most recent pickup function shows the latest donation by the store.  
- Store owner can access their donation history.
- Refresh button is included to refresh any new entries. 

#Notification: 
- An admin check reminder notification is sent every day at same time if there are any missing or unverified entries.  
- You can login into Admin using any registered admin account or register a new admin account to test the notifcation reminder. 
- A local notification will be sent to the admin if there are any missing or unverified entries that day by 6 PM. 
- Admin can also click on the bell icon to let volunteer/driver know the store they should visit next using bell icon in stores_notification.dart. 

#For Testing:
- Volunteer login- usertesting@gmail.com, pass: 123456
- Admin Login - admintesting@gmail.com, pass: 123456
- Admin reports email - replace shubham.verma@mytwu.ca (in reports.dart) with an email of yours. 
- Store Owner Login- use code: Z03N1N


#Notes:
- All data is stored securely in Firestore.
- Ensure entries are accurate before submission to maintain data integrity.

#Coding Style:
We followed the Dart Style Guide for code consistency:
https://dart.dev/guides/language/effective-dart/style

#Resources:
- Flutter Documentation: https://docs.flutter.dev/
- Firebase Documentation: https://firebase.google.com/docs
- Dart Style Guide: https://dart.dev/guides/language/effective-dart/style
