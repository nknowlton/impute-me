library("shiny")


source("/home/ubuntu/srv/impute-me/functions.R")


# Define server logic for random distribution application
shinyServer(function(input, output) {
	
	output$table1 <- renderDataTable({ 
		# Take a dependency on input$goButton
		
		if(input$goButton == 0){
			return(NULL)
		}else if(input$goButton > 0) {
			print(paste("Ok",input$goButton))
		}
	  show_measured <- input$show_measured
	  uniqueID<-isolate(gsub(" ","",input$uniqueID))
		if(nchar(uniqueID)!=12)stop(safeError("uniqueID must have 12 digits"))
		if(length(grep("^id_",uniqueID))==0)stop(safeError("uniqueID must start with 'id_'"))
		pDataFile<-paste("/home/ubuntu/data/",uniqueID,"/pData.txt",sep="")
		
		if(!file.exists(paste("/home/ubuntu/data/",uniqueID,sep=""))){
			Sys.sleep(3) #wait a little to prevent raw-force fishing	
			stop(safeError("Did not find a user with this id"))
		}
		
		
		#Get gender
		# gender<-read.table(pDataFile,header=T,stringsAsFactors=F,sep="\t")[1,"gender"]
		
		
		BRCA_table_file <-"/home/ubuntu/srv/impute-me/BRCA/SNPs_to_analyze.txt"
		BRCA_table<-read.table(BRCA_table_file,sep="\t",header=T,stringsAsFactors=F)

		rownames(BRCA_table)<-BRCA_table[,"SNP"]
		BRCA_table[BRCA_table[,"chr_name"]%in%13,"gene"]<-"BRCA2"
		BRCA_table[BRCA_table[,"chr_name"]%in%17,"gene"]<-"BRCA1"
		
		
		#handle 23andme special SNPs
		special_snps <- c("i4000377","i4000378","i4000379")
		BRCA_table["i4000377","gene"]<-"BRCA1"
		BRCA_table["i4000378","gene"]<-"BRCA1"
		BRCA_table["i4000379","gene"]<-"BRCA2"
		BRCA_table[special_snps,"consequence_type_tv"]<-"Direct from 23andme"
		
		
		#get genotypes 
		genotypes<-get_genotypes(uniqueID=uniqueID,request=BRCA_table)

				
		# #retry genotypes in a special input-only mode
		# BRCA_table_input <- BRCA_table
		# BRCA_table_input[,"chr_name"] <- "input"
		# genotypes_input<-get_genotypes(uniqueID=uniqueID,request=BRCA_table_input,namingLabel="BRCA")
		# 
		# #check what extra is found
		# found_imputed <- rownames(genotypes)[!is.na(genotypes[,"genotype"])]
		# found_input <- rownames(genotypes_input)[!is.na(genotypes_input[,"genotype"])]
		# new <- found_input[!found_input%in%found_imputed]
		# genotypes[new,"genotype"] <- genotypes_input[new,"genotype"]
		# 
		# This would fix the genotypes missing - but it opens up a huge bag of troubles, 
		# because it also means that we have to make sure that *any* notation that input
		# data comes with is properly taken care of. For example - it's a little random
		# if a DTC vendor write -/- or D/D or T/T or I/I for an indel. So, the problem
		# is that if we write "normal genotype T/T, and that vendor chose to write I/I
		# then it is quite easy to misunderstand as something bad. 
		#
		# So -- it's concluded that impute.me will not fix this right now, but rather throw
		# away genotypes that don't make it through imputation, including indels etc. Because
		# fixing would mean that the entire advantage of strand-alignment and QC implicit in
		# imputation would be lost in this particular module. And risks of error. So - altogether
		# better to just not report anything. BRCA needs sequencing anyway, so it's grasping at 
		# straws to try to improve it.
		
		
		
		BRCA_table[,"Your genotype"]<-genotypes[rownames(BRCA_table),]

		
		#check if the 23andme-ones are - reported insted of D reported
		if(length(grep("-",BRCA_table[special_snps,"Your genotype"]))>0){
		  BRCA_table[special_snps,"Your genotype"] <- gsub("-","D",BRCA_table[special_snps,"Your genotype"])
		}
		
		#remove non measured if needed
		if(show_measured){
		  BRCA_table<-BRCA_table[!is.na(BRCA_table[,"Your genotype"]),]
		}
		
		#order so pathogenic is always on top
		order<-c('Pathogenic','Likely pathogenic','Conflicting interpretations of pathogenicity','Uncertain significance','not provided','Likely benign','Benign')
		BRCA_table[,"clinvar"]<-factor(BRCA_table[,"clinvar"],levels=order)
		BRCA_table<-BRCA_table[order(BRCA_table[,"clinvar"]),]
		
		
		BRCA_table<-BRCA_table[,c("SNP","gene","Your genotype","normal","clinvar","polyphen_prediction","sift_prediction","consequence_type_tv")]
  colnames(BRCA_table) <- c("SNP","gene","Your genotype","normal","ClinVar","Polyphen","Sift","Type")
		
		
		
		#write the score to the log file
		log_function<-function(uniqueID){
			user_log_file<-paste("/home/ubuntu/data/",uniqueID,"/user_log_file.txt",sep="")
			m<-c(format(Sys.time(),"%Y-%m-%d-%H-%M-%S"),"BRCA",uniqueID)
			m<-paste(m,collapse="\t")
			if(file.exists(user_log_file)){
				write(m,file=user_log_file,append=TRUE)
			}else{
				write(m,file=user_log_file,append=FALSE)
			}
		}
		try(log_function(uniqueID))
		
				
		return(BRCA_table)
		
		
		
	})
	
})


