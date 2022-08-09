#!/bin/bash

#usage:  
#
#	. path/to/ld.sh				#step 1. load the functions up
#	declare -A myLD  			#step 2. declare a bash dictionary as the underlying data store for the ld.sh functionality
#						#step 3. use the functionality as in the examples below
#	ld myLD set key value 			#sets the key value
#	ld myLD get key				#gets the key value (returned to std out)
#	ld myLD get key myValueVar 		#gets the key value and sets myValueVar to that value.  nothing is echoed back.
#	ld myLD increment			#increments the current step.  
#	ld myLD rollback 3			#rolls the state of the dictionary back to step 3, removing any mutations that happened after this.  and resets the current step to 3.
#	ld myLD laststep key			#gets the last step the key was mutated on

#the underlying design concept:
#	a dictionary structure that keeps an immutable record of all of the mutations that happen to it during "prior steps".
#	at initial construction (ie. first use of ld) the current step is set to 0.  
#	incrementing the current step will "freeze" the state of the prior steps as a entries in the dictionary.  
#	any mutation of a pre-existing key/value set during a prior step will update the public key/value "for the current step", but not affect the prior entries.

#how this is implemented:
#	a key of __step__ is kept in the dictionary that holds the current step.  
#		this is a reserved key.
#		the initial value is 0.
#		increment calls will increment this value.
#		rollback calls will reset the value to the rollback level. 
#	a key of "myKey" is kept internally as "myKey__{currentStep}"
#		mutations will mutate "myKey__{currentStep}"
#		reads will grab the latest value of "myKey__{stepX}" where stepX is less than or equal to {currentStep}.
#	upon a rollback to a particular step all entries that happened on a greater step value will be removed.

#what is the utility of this paradigm?
#	- having immutable values of data that you can tie to particular stages of mutation is useful for performing rollbacks and for knowing at what stage a value was mutated.
#	- in a workflow it is often desireable for data gathered during a prior step to be available during later steps but to not be settable.  
#		- the analogy of a book where every time a new chapter is written it can reference the prior chapters but changing the priors could be incompatible with the addition.  
#		- for example.  one has some ui functionality where there is a sequence of nested dialogs that have to be completed.  this will mutate some larger "unit of work" state
#			at each step.  being able to rollback state to a particular step of that workflow would be useful.  the immutable audit history of a key gives this guarantee.

#usage:	ld myLD set key value 			#sets the key value
#usage:	ld myLD get key				#gets the key value (returned to std out)
#usage:	ld myLD get key myValueVar 		#gets the key value and sets myValueVar to that value.  nothing is echoed back.
#usage:	ld myLD increment			#increments the current step.  
#usage:	ld myLD rollback 3			rolls the state of the dictionary back to step 3, removing any mutations that happened after this.  and resets the current step to 3.
#usage:	ld myLD laststep key			#gets the last step the key was mutated on
ld()
{
	declare -n LD="$1"  #pass dictionary by ref
	if [[ -z "$LD" ]]; then
		echo "invalid operation.  dictionary does not exist"
		return 1
	fi
	
	#initialization check
	local STEP
	STEP="${LD[__step__]}"
	
	#if the step is not initialized we must init the entire dictionary 
	if [[ -z "$STEP" ]]; then
		#get all the existing entries and copy them to temp dictionary
		declare -N TEMPHASH 
		local KEY KEYVAL
		for KEY in "${!LD[@]}"; do
			KEYVAL="${LD[$KEY]}"
			TEMPHASH[$KEY]="$KEYVAL"
		done
		
		#remove them and re-add them with the stepped key
		for KEY in "${!TEMPHASH[@]}"; do
			unset LD[$KEY]
			LD[$KEY__0]="${TEMPHASH[$KEY]}"
		done
		
		#clean up
		unset TEMPHASH
		unset KEY
		unset KEYVAL
		
		#set step to 0
		LD[__step__]=0
		STEP=0 
	fi
	
	local OP="$2"
	case "$OP" in
	"set" )
		local KEY="$3"
		local VALUE="$4"
		LD["$KEY"__"$STEP"]="$VALUE"
		return 0
		;;
	"get" )
		local KEY="$3"
		local VALUE
		
		#decrementing from current step to 0 we check for a value to exist and return first match
		local I
		for ((I=STEP; I>=0; I--))
		do
			VALUE="${LD[$KEY__$I]}"
			if [[ ! -z "$VALUE" ]]; then
				#return this
				if [[ -z "$4" ]]; then
					echo "$VALUE"
					return 0
				else
					declare -n VALVAR="$4"
					VALVAR="$VALUE"
					return 0
				fi
			fi
		done
		return 1 #not found
		;;
	"increment" )
		$(( STEP++ ))
		LD[__step__]="$STEP"
		return 0
		;;
	"rollback" )
		local ROLLBACK="$3"
		if [[ "$ROLLBACK" -lt 0 ]]; then
			echo "rollback out of bounds.  low."
			return 1
		fi 
		if [[ "$ROLLBACK" -gt "$STEP" ]]; then
			echo "rollback out of bounds.  high."
			return 1
		fi
		STEP="$ROLLBACK"
		
		#now get all of the keys greater than this step
		declare -n DELKEYS 
		local KEY KEYSTEP
		for KEY in "${!LD[@]}"; do
			KEYSTEP=${KEY##*__}
			if [[ "$KEYSTEP" -gt "$STEP" ]]; then
				DELKEYS+=("$KEY")
			fi
		done
		
		#remove them and re-add them with the stepped key
		for KEY in "${DELKEYS[@]}"; do
			unset LD[$KEY]
		done
		
		LD[__step__]="$STEP"
		return 0
		;;
		
	"laststep" )
		local KEY="$3"
		local VALUE
		
		#decrementing from current step to 0 we check for a value to exist and return first match
		local I
		for ((I=STEP; I>=0; I--))
		do
			VALUE="${LD[$KEY__$I]}"
			if [[ ! -z "$VALUE" ]]; then
				#return this
				echo "$I"
				return 0
			fi
		done
		return 1 #not found
		;;

	*)
		echo "unknown command"
		return 1
		;;
	esac
	
	return 1
}
	
