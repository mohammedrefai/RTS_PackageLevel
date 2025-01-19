# Static Package Level Regression Test Selection

## This GitHub repository contains the following:
 - The Bash script file (file name is: downloadJava8.sh) we used to:
    - Download, compile, and run the test cases for all 885 revisions of the 9 subjects used in our experiments.
    - Integrate the RTS tools Ekstazi and STARTS plugins to each revision and run these RTS tools and store their output.
    - Run JDeps tool at the classl-level and package-level to extract the dependencies among classes/packages of each of the 885 revisions.  
 - The SHA identifiers of the subjects: Each subject is associated with a text file containing the SHA identifiers of its revisions that were downloaded and used in the experimental evaluation. The SHA identifier enable users to retrieve the source code of the corresponding revision of a subject from the subject's GitHub repository.
