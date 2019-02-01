/*
JSON Object parameters received from SSP server--
1. user
2. Password
3. VM Name
4. Datacenter
5. VM Template
6. VM Notes
7. Folder
8. User Mail
9. Date

Sample JSON Object--
{
"user":"SSP_Server",
"Password":"Server@123",
"Datacenter":"DC1",
"Mail":"TestMail@domain.com",
"VM_Name":"TestAPI002",
"Folder":"\"/DC1/Prod/Test\"",
"Template":"Template-01",
"Notes":"\"Awesome!!! This is a test VM deployed by Jana \"",
"Date":"2-1-2018"
}

Note --
If the parameter consists multiple words, then it must use double quotes explicitly "\"xxxx yyyy\""


*/
var express = require('express');
var app = express();
var MongoClient= require('mongodb').MongoClient;
var url = ('mongodb://localhost/');
var empty = require('is-empty');


app.use(express.json());

//Post Method Handling
app.post('/', function(request, response){
	
	try
	{
	var jsonContent = request.body;
	}
	
	catch (err)
	{
		console.log("Parameters Errors");
        response.end("Parameters Errors");
        return;
	}
	
//Function-1
MongoClient.connect(url,{useNewUrlParser: true },function(err, client) {

//Getting User from JSON object
var user_1 = jsonContent.user;

//Connecting to DB
var record = client.db('Users');

//Query to execute with User
var query = { User: user_1 };

//Function-2
record.collection("Login").find(query).toArray(function(err, result) {

try
{
var password_1 = result[0].Password;
}

catch(err)
{
console.log("Authentication Error : User Name provided for this API is not valid");
client.close();
response.end("Authentication Error : User Name provided for this API is not valid");
return;
}

try{
if (jsonContent.Password !== password_1)
{
	throw "Password provided for this API is not matching";
}	
}

catch(err)
{
console.log("Authentication Error : "+ err);
client.close();
response.end("Authentication Error : "+ err);
return;
}

try
{

if (empty(jsonContent.Datacenter))
{
	throw "Datacenter value is not provided";
}	

else if (empty(jsonContent.Mail))
{
	throw "Mail value is not provided";
}	

else if (empty(jsonContent.VM_Name))
{
	throw "VM_Name value is not provided";
}	

else if (empty(jsonContent.Folder))
{
	throw "Folder location value is not provided";
}	

else if (empty(jsonContent.Template))
{
	throw "VM Template value is not provided";
}	

else if (empty(jsonContent.Notes))
{
	throw "VM Notes value is not provided";
}	

else if (empty(jsonContent.VM_Date))
{
	throw "VM_Date value is not provided";
}

}

catch(err)
{
console.log("Parameter Error : "+ err);
client.close();
response.end("Parameter Error : "+ err);
return;
}



//Inserting data into MongoDB - Log 
record.collection("Log").insertOne(jsonContent,function (err,result) {
	if(err)
	{
		console.log("Error in inserting JSON object into DB ");
		client.close();
		response.end("Error in inserting JSON object into DB ");
		return;
	}
	
	else
	{
		console.log ("Data successfully inserted into DB");
	}
});

client.close();   
   
var spawn = require("child_process").spawn,child;

var ans = "C:\\deployVM\\Deploy_VM.ps1 -VM_Name " + jsonContent.VM_Name + " -Datacenter " +jsonContent.Datacenter + " -VM_Template " +jsonContent.Template + " -VM_Notes " +jsonContent.Notes + " -VM_Folder " +jsonContent.Folder + " -User_Mail " +jsonContent.Mail;
child = spawn("powershell.exe",[ans]);
   
//
child.stdout.on("data",function(data){
    console.log("Powershell Data: " + data);
});
child.stderr.on("data",function(data){
    console.log("Powershell Errors: " + data);
	//response.end("Errors while executing the script on the backend ");
});
child.on("exit",function(){
    console.log("Powershell Script finished");
});
   
child.stdin.end(); //end input
  
response.end("Request is sent Successfully to the server " + jsonContent.VM_Name);
console.log("VM is being created with a name of:", jsonContent.VM_Name);

});
//End of Function-2

});
//End of Function-1

});

app.listen(3000);