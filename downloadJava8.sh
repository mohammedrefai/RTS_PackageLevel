#!/bin/env bash

#export JAVA_HOME='/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.242.b08-0.fc30.x86_64/'

ROOTDIR=$(dirname "$(readlink -f "$0")")  # the directory that contains this script file and the folders: repositories, revisions, and workingDir

PATH_TO_SHA_FILES=$2

echo "root is:$ROOTDIR"
echo "path to SHAs is:$PATH_TO_SHA_FILES"
REPOSITORIES_DIR="$ROOTDIR/repositories"
REVISIONS_DIR="$ROOTDIR/revisions"
WORKING_DIR="$ROOTDIR/workingDir"
STARTS_DIFF="$ROOTDIR/startsDiff"
EKSTAZI_DIFF="$ROOTDIR/ekstaziDiff"
LOG="$ROOTDIR/log.txt"
NEXT_REVISION_DIR="$ROOTDIR/nextDir"
TEMP="$ROOTDIR/temp"

rm -rf "$REVISIONS_DIR"
rm -rf "$REPOSITORIES_DIR"
rm -rf "$WORKING_DIR"
rm -rf "$STARTS_DIFF"
rm -rf "$EKSTAZI_DIFF"
rm -rm "$LOG"
rm -rm "$NEXT_REVISION_DIR"
rm -rm "$TEMP"

mkdir "$REVISIONS_DIR" # contains the cloned repositories
mkdir "$REPOSITORIES_DIR"    # contains the checked-out revisions of each subject
mkdir "$WORKING_DIR"   # working directory to run Ekstazi and STARTS 
mkdir "$NEXT_REVISION_DIR"
mkdir "$TEMP"

# add bcel to the class path 
#export CLASSPATH=$CLASSPATH:$ROOTDIR/lib/*

# Ekstazi Plugin
_Ekstazi__PROFILE=$(cat <<EOF
        <profile>
            <id>ekstazip</id>
            <activation>
                <property>
                    <name>ekstazi</name>
                </property>
            </activation>
            <build>
                <plugins>
                  <plugin>
                      <groupId>org.ekstazi</groupId>
                      <artifactId>ekstazi-maven-plugin</artifactId>
                      <version>5.3.0</version>
                      <executions>
                          <execution>
                              <id>ekstazi</id>
                              <goals>
                                  <goal>select</goal>
                              </goals>
                          </execution>
                      </executions>
                  </plugin>
<!-- EKSTAZI -->
                </plugins>
            </build>
        </profile>
EOF
)
_Ekstazi__PROFILE=$(echo ${_Ekstazi__PROFILE} | sed 's/ //g')

# Integrating Ekstazi Plugin in pom.xml
function Ekstazi.integrate() {
        local repo="${1}"; shift
        #echo "repo is" ${repo}
        ( cd ${repo};
                for pom in $(find -name "pom.xml"); do
                        local has_profiles=$( grep 'profiles' ${pom} | wc -l )
                        if [ ${has_profiles} -eq 0 ]; then
                                sed -i 'sX</project>X<profiles>'${_Ekstazi__PROFILE}'</profiles></project>Xg' ${pom}
                        else
                                sed -i 'sX</profiles>X'${_Ekstazi__PROFILE}'</profiles>Xg' ${pom}
                        fi
                done
        )



        #project.xml
        ( cd ${repo};
                for proj in $(find -name "project.xml"); do
                        local has_profiles=$( grep 'profiles' ${proj} | wc -l )
                        if [ ${has_profiles} -eq 0 ]; then
                                sed -i 'sX</project>X<profiles>'${_Ekstazi__PROFILE}'</profiles></project>Xg' ${proj}
                        else
                                sed -i 'sX</profiles>X'${_Ekstazi__PROFILE}'</profiles>Xg' ${proj}
                        fi
                done
        )
}








# STARTS Plugin

_Starts__PROFILE=$(cat <<EOF
        <profile>
            <id>startsp</id>
            <activation>
                <property>
                    <name>starts</name>
                </property>
            </activation>
            <build>
                <plugins>
                         <plugin>
                                <groupId>edu.illinois</groupId>
                                <artifactId>starts-maven-plugin</artifactId>
                                <version>1.4-SNAPSHOT</version>
                         </plugin>
                </plugins>
            </build>
        </profile>
EOF
)
_Starts__PROFILE=$(echo ${_Starts__PROFILE} | sed 's/ //g')

# Integrating STARTS Plugin in pom.xml
function Starts.integrate() {
        local repo="${1}"; shift
        ( cd ${repo};
                for pom in $(find -name "pom.xml"); do
                        local has_profiles=$( grep 'profiles' ${pom} | wc -l )
                        if [ ${has_profiles} -eq 0 ]; then
                                sed -i 'sX</project>X<profiles>'${_Starts__PROFILE}'</profiles></project>Xg' ${pom}
                        else
                                sed -i 'sX</profiles>X'${_Starts__PROFILE}'</profiles>Xg' ${pom}
                        fi
                done
        )
}





IFS=$'\n' read -d '' -r -a repos < "$ROOTDIR/repositories.txt"
echo "number of GIT repositories is: "  ${#repos[@]}

echo "git clone all repositories inside the $REPOSITORIES_DIR"
for ((numRepo=0;  numRepo < ${#repos[@]} ; numRepo += 1)); do
        (cd "$REPOSITORIES_DIR" && git clone "${repos[$numRepo]}")
done

# iterate through the cloned repositories to download all of their revisions
for i in $REPOSITORIES_DIR/*; do
if [ -d "$i" ]; then
      subjectName=$(basename $i)
      # copy the the SHA file to the corresponding subject directory
      cp "$PATH_TO_SHA_FILES/$subjectName.txt"  "$i/"

      # read the subject hashes to an array
      IFS=$'\n' read -d '' -r -a subject_Hashes < "$i/$subjectName.txt"

      #echo ${#subject_Hashes[@]}

      next_hash=""
      current_hash=""

      rm -rf "$STARTS_DIFF"
      mkdir "$STARTS_DIFF"
      
      rm -rf "$EKSTAZI_DIFF"
      mkdir "$EKSTAZI_DIFF"
      
      NEXT_REV_DIR=""

      let totalNumRevs=0
      for ((num=0;  num<${#subject_Hashes[@]} ; num += 1))
       do
       
       		if [[ $totalNumRevs -ge 100 ]]; then
    			break
  		fi
  		
          current_hash="${subject_Hashes[$num]}"  # store the current hash
	  

          (cd "$i" && git checkout "$current_hash" &> "$i/GitCommitComment.txt") # check out the current revision
          (cp -r -f -a "$i/."  "$WORKING_DIR/") # copy the current revision to the working directory, where Ekstazi and STARTS will be applied.
          (cp -r -f -a "$i/."  "$STARTS_DIFF/")
          (cp -r -f -a "$i/."  "$EKSTAZI_DIFF/")                       
          
          
          # run STARTS with the current revision
          (cd "$WORKING_DIR" && Starts.integrate "$WORKING_DIR/") 
	  (cd "$WORKING_DIR" && mvn starts:select -Drat.skip=true -DupdateSelectChecksums=true -DdepFormat=CLZ -Pstartsp &> "$WORKING_DIR/StartsRun.txt")
	  
	  # run Ekstazi with the current revision
	  (cd "$WORKING_DIR" && mvn clean &> "$WORKING_DIR/cleanResult.txt")
          (cp -f -a "$ROOTDIR/.ekstazirc" "$WORKING_DIR/")
          (cd "$WORKING_DIR" && Ekstazi.integrate "$WORKING_DIR/")
          #(cd "$WORKING_DIR" && mvn ekstazi:select -Pekstazip &> "$WORKING_DIR/EkstaziSelect.txt")
          (cd "$WORKING_DIR" && mvn ekstazi:ekstazi -Drat.skip=true -Pekstazip &> "$WORKING_DIR/EkstaziRun.txt")
          
          #(cd "$WORKING_DIR" && printf 'Ekstazi time: ' > times.txt)
          #(cd "$WORKING_DIR" && awk '/time:/ {print $4}' EkstaziSelect.txt >> times.txt)
          #(cd "$WORKING_DIR" && printf 'Starts time: ' >> times.txt)
          #(cd "$WORKING_DIR" && awk '/time:/ {print $4}' StartsResult.txt >> times.txt)
          
          
          if grep -q "BUILD SUCCESS" "$WORKING_DIR/EkstaziRun.txt"; then
            if grep -q "BUILD SUCCESS" "$WORKING_DIR/StartsRun.txt"; then
            
            
            
          	if [[ -n "$next_hash" ]]; then
                      		
                      		(diff -r "$REVISIONS_DIR/$NEXT_REV_DIR/.starts"  "$WORKING_DIR/.starts" > "$TEMP/linuxDiffStartsDetailed.txt")
                      		
                      		if grep -q "workingDir/target/" "$TEMP/linuxDiffStartsDetailed.txt"; then
                      		
                      				echo "${subjectName}V${num}_${current_hash}"
                      				
                      				# process working directory data
                      				(cd "$WORKING_DIR/"  && jdeps -v "$WORKING_DIR/target"  >> "$WORKING_DIR/jdepsClassLevel.txt")
                     				(cd "$WORKING_DIR/"  && jdeps "$WORKING_DIR/target"  >> "$WORKING_DIR/jdepsPackageLevel.txt")
                     				
                     				echo "nextHash: $next_hash ; currHash: $current_hash" > "$REVISIONS_DIR/$NEXT_REV_DIR/linuxDiffStartsTestClasses.txt" 
                     				(diff -r -q -I 'jar:file:' "$REVISIONS_DIR/$NEXT_REV_DIR/.starts"  "$WORKING_DIR/.starts" >> "$REVISIONS_DIR/$NEXT_REV_DIR/linuxDiffStartsTestClasses.txt")
                     				
                     				echo "nextHash: $next_hash ; currHash: $current_hash" > "$REVISIONS_DIR/$NEXT_REV_DIR/linuxDiffEkstaziTestClasses.txt" 
                     				(diff -r -q -I 'jar:file:' "$REVISIONS_DIR/$NEXT_REV_DIR/.ekstazi"  "$WORKING_DIR/.ekstazi" >> "$REVISIONS_DIR/$NEXT_REV_DIR/linuxDiffEkstaziTestClasses.txt")
                     				
                     				echo "nextHash: $next_hash ; currHash: $current_hash" > "$REVISIONS_DIR/$NEXT_REV_DIR/linuxDiffStartsDetailed.txt" 
                     				(diff -r "$REVISIONS_DIR/$NEXT_REV_DIR/.starts"  "$WORKING_DIR/.starts" >> "$REVISIONS_DIR/$NEXT_REV_DIR/linuxDiffStartsDetailed.txt")
                     				
                      		          	# create a folder to store the current revision in it                                   
                     	        		mkdir "$REVISIONS_DIR/${subjectName}V${num}_${current_hash}"
                                		# copy the current revision to the new folder 
                                		cp -r -f -a "$WORKING_DIR/."  "$REVISIONS_DIR/${subjectName}V${num}_${current_hash}"
                      				
                      				
                      				(cd "$STARTS_DIFF" && mvn clean &> /dev/null)
          					(cd "$STARTS_DIFF" && Starts.integrate "$STARTS_DIFF/")
          					(cd "$STARTS_DIFF" && mvn starts:diff -Drat.skip=true -Pstartsp &> "$STARTS_DIFF/StartsDiff.txt")
          					(cd "$STARTS_DIFF"  && mvn starts:select  -Drat.skip=true -DupdateSelectChecksums=true -Pstartsp &> "$STARTS_DIFF/StartsAffectedTests.txt")
          
          					#(cd "$EKSTAZI_DIFF" && mvn clean &> /dev/null)
          					#(cd "$EKSTAZI_DIFF" && Ekstazi.integrate "$EKSTAZI_DIFF/")
                      				#(cd "$EKSTAZI_DIFF"  && mvn ekstazi:ekstazi -Drat.skip=true -Pekstazip &> "$EKSTAZI_DIFF/ekstaziAffectedTests.txt")
          					
                      				 (cd "$STARTS_DIFF" && git ls-files -z | xargs -0 rm -f)
       					         (cd "$WORKING_DIR" && git ls-files -z | xargs -0 rm -f)

       				                 (cp -r -f -a "$NEXT_REVISION_DIR/."  "$STARTS_DIFF/")
       				                 (cp -r -f -a "$NEXT_REVISION_DIR/."  "$WORKING_DIR/")
       				                 
                      				(cd "$STARTS_DIFF" && mvn clean &> /dev/null)
          					(cd "$STARTS_DIFF" && Starts.integrate "$STARTS_DIFF/")
          					(cd "$STARTS_DIFF" && mvn starts:diff  -Drat.skip=true -Pstartsp &> "$REVISIONS_DIR/$NEXT_REV_DIR/StartsDiff.txt")
          					(cd "$STARTS_DIFF"  && mvn starts:select -Drat.skip=true -DupdateSelectChecksums=true -Pstartsp &> "$REVISIONS_DIR/$NEXT_REV_DIR/StartsAffectedTests.txt")
          
          					(cd "$WORKING_DIR" && mvn clean &> /dev/null)
          					(cp -f -a "$ROOTDIR/.ekstazirc" "$WORKING_DIR/")
          					(cd "$WORKING_DIR" && Ekstazi.integrate "$WORKING_DIR/")
                      				(cd "$WORKING_DIR"  && mvn ekstazi:ekstazi -Drat.skip=true -Pekstazip &> "$REVISIONS_DIR/$NEXT_REV_DIR/ekstaziAffectedTests.txt")
                      		
                      				if grep -q "BUILD SUCCESS" "$REVISIONS_DIR/$NEXT_REV_DIR/ekstaziAffectedTests.txt"; then
                      				            echo "BUILD SUCCESS Ekstazi:ekstazi" > "$REVISIONS_DIR/$NEXT_REV_DIR/BuildSuccessStatus.txt"
                      				            
                      				            if grep -q "BUILD SUCCESS" "$REVISIONS_DIR/$NEXT_REV_DIR/StartsDiff.txt"; then
            					                    echo "BUILD SUCCESS Starts:diff" >> "$REVISIONS_DIR/$NEXT_REV_DIR/BuildSuccessStatus.txt"
            					                    
            					                    if grep -q "BUILD SUCCESS" "$REVISIONS_DIR/$NEXT_REV_DIR/StartsAffectedTests.txt"; then
            					            		  echo "BUILD SUCCESS Starts:select" >> "$REVISIONS_DIR/$NEXT_REV_DIR/BuildSuccessStatus.txt"
            					            		  echo "$subjectName $num $current_hash  pass" >> "$LOG"
            							    else
								           echo "$subjectName $num $current_hash  fail" >> "$LOG"
            							    fi
            					            else
            					            	    echo "$subjectName $num $current_hash  fail" >> "$LOG"
            						    fi
                      				else
                      				            echo "$subjectName $num $current_hash  fail" >> "$LOG"
                      				fi
                      				
                      				
            					
            					
            					
                      		                # process Git diff result to convert it to the format that is readable by FLiRTS 2
                                                (cd "$ROOTDIR" && ./lib/formatStartsDiff.py "$REVISIONS_DIR/$NEXT_REV_DIR/StartsDiff.txt" "$REVISIONS_DIR/$NEXT_REV_DIR/AdaptedClassesSet.txt")
                                                
                                                echo "nextHash: $next_hash ; currHash: $current_hash" > "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt" 
                                                echo "<added classes>" >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt" 
                      				(cd "$REVISIONS_DIR/$NEXT_REV_DIR/"  && git diff --name-only --diff-filter=A "$current_hash" "$next_hash" -- "*.java"  >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt")
                     				echo "<deleted classes>" >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt"                               
                     				(cd "$REVISIONS_DIR/$NEXT_REV_DIR/"  && git diff --name-only --diff-filter=D "$current_hash" "$next_hash" -- "*.java"  >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt")
                     				echo "<modified classes>" >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt"                                    
                     				(cd "$REVISIONS_DIR/$NEXT_REV_DIR/"  && git diff --name-only --diff-filter=M "$current_hash"  "$next_hash" -- "*.java"  >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt")
                     				echo "<renamed classes>" >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt"                                    
                     				(cd "$REVISIONS_DIR/$NEXT_REV_DIR/"  && git diff --name-only --diff-filter=R "$current_hash"  "$next_hash" -- "*.java"  >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt")
                      				echo "<all Changes>" >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt"                                    
                     				(cd "$REVISIONS_DIR/$NEXT_REV_DIR/"  && git diff "$current_hash" "$next_hash"  >> "$REVISIONS_DIR/$NEXT_REV_DIR/GitDiffsDetails.txt")
                     				
                     				
                     				
                                		
                                		NEXT_REV_DIR="${subjectName}V${num}_${current_hash}"
                                		
                                		let totalNumRevs=totalNumRevs+1
                                		echo "$totalNumRevs"
                      		
                      		               next_hash="$current_hash"
                      		               (cd "$NEXT_REVISION_DIR" && rm -r -f {*,.*} &>/dev/null)
                      		               (cp -r -f -a "$i/."  "$NEXT_REVISION_DIR/")
                      		else
                      		       echo "Diff between $next_hash and $current_hash does not include source code changes" 
                      		fi
          
          
          	#elif [[ $num -eq 0 ]]; then 
          	else
          
          			echo "${subjectName}V${num}_${current_hash}"
                                
          			
          			(cd "$WORKING_DIR/"  && jdeps -v "$WORKING_DIR/target"  >> "$WORKING_DIR/jdepsClassLevel.txt")
                     		(cd "$WORKING_DIR/"  && jdeps "$WORKING_DIR/target"  >> "$WORKING_DIR/jdepsPackageLevel.txt")
          
                                # create a folder to store the current revision in it                                   
                     	        mkdir "$REVISIONS_DIR/${subjectName}V${num}_${current_hash}"
                                # copy the current revision to the new folder 
                                cp -r -f -a "$WORKING_DIR/."  "$REVISIONS_DIR/${subjectName}V${num}_${current_hash}"
                                
                                NEXT_REV_DIR="${subjectName}V${num}_${current_hash}"
                                
                                let totalNumRevs=totalNumRevs+1
                                echo "$totalNumRevs"
                                
                                next_hash="$current_hash"
                                (cp -r -f -a "$i/."  "$NEXT_REVISION_DIR/")
          
          
          	fi
            		
                   # record direct invocations of test classes                                  
                   #(cd "$ROOTDIR" && java utils.DirectInvocationsRecorder "$WORKING_DIR/")
                   
            else
                   echo "Running STARTS with the revision $i did not produce BUILD SUCCESS, so this revision is discarded"
            fi
         else
            echo "Running Ekstazi with the revision $i did not produce BUILD SUCCESS, so this revision is discarded"
         fi

        # next_hash="$current_hash"
       (cd "$WORKING_DIR" && rm -r -f {*,.*} &>/dev/null)
       (cd "$STARTS_DIFF" && rm -r -f {*,.*} &>/dev/null)
       (cd "$EKSTAZI_DIFF" && rm -r -f {*,.*} &>/dev/null)
       (cd "$TEMP" && rm -r -f {*,.*} &>/dev/null)
       (sync;)
       (sleep 10)
      
	
  done       

fi
done

rm -rf "$STARTS_DIFF"
rm -rf "$EKSTAZI_DIFF"
rm -rf "$NEXT_REVISION_DIR"
rm -rf "$TEMP"

echo "Total number of downloaded revisions is: $totalNumRevs"
