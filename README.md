# External Project

Project Scheme:  
![Scheme](/screenshots/scheme.png)  

## How does it work:  
We have 2 AWS EC2 instances created using [Terraform](project_jenkins_s3.tf). Further configurations are made via Ansible. [playbook.yml](playbook.yml) for Jenkins master server and [playbook_docker.yml](playbook_docker.yml) for Jenkins agent with Docker.  

It is required to set MySQL database credentials into a file called **env** to use them in [docker-compose.yml](/docker-compose.yml) file.  
Example of **env** file:  
<pre>
MYSQL_ROOT_PASSWORD=Password
MYSQL_USER=user
MYSQL_PASSWORD=Password2
</pre>  
The database password should also be specified in Jenkins variable called **slave_database**  
The **credentials** file is used to store key for Terraform IAM user.  
You will also require to have ssh key pairs for Jenkins SSH agent as well as a .pem file which is used by Ansible for a configuration.  
 
The server was configured to download an archive with jenkins folder from **S3 bucket**. However, there is no guarantee that the bucket is still present.    
Jenkins pipeline:  
<pre>
pipeline {
    agent {label 'AWS_agent'}
    environment {
        db_pass = credentials('slave_database') #Adding environmental variable with database password.
    }
    stages {
        stage('Git_pull'){
            steps{
                script{
                    git branch: 'main',
                credentialsId: 'git_key',
                url: 'git@github.com:CryOneButWhy/Project.git' #Pulling working repository
                } 
                
            }
                
            }
        
        stage('Links change') {
            environment {
                 IP = sh(returnStdout: true, script: 'dig +short myip.opendns.com @resolver1.opendns.com').trim() # Specifying public IP of the instance
            }
            steps{
                sh "sed -in 's/localhost:8080/${IP}:8081/g' data.sql" #Changing links in database
                sh "echo the links are changed"
            }
        }
        stage('Bd_upload'){
            steps{
                sh 'sudo docker exec -i  wordpress_db_1 mysql -u root -p$db_pass wordpress < data.sql' #Uploading a new database file
                sh 'echo Database is uploaded'
            }
        }
    }
}
</pre>  