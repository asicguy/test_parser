# Based upon ideas from the course "Interactive Programming Using Python"

# The simplicity of this is the modulo function. by redefining the three 
# inputs as numerical values, it becomes trivial to determine the winner

# utensil    Numerical value
# rock       0
# paper      1
# scissors   2

# need random for computer guess
import random 

# helper functions

#converts number to a name
def num2name(number):
    if number == 0:
        return 'rock'
    elif number == 1:
        return 'paper'
    else:
        return 'scissors'
   
# converts name to number
def name2num(name):
    if name == 'rock':
        return 0
    elif name == 'paper':
        return 1
    else:
        return 2 #scissors

def PaperScissorsRock(guess): 
    
    # convert name to player_number using name_to_number
    my_number = name2num(guess)

    # computer guess
    comp_number = random.randrange(0,3)
    
    # The cool thing about RPS is that we can simply take the modulo of the 
    # difference.
    
    difference = (my_number - comp_number) % 3
    
    # use if/elif/else to determine winner
    # each choice wins against the preceding two choices 
    # and loses against the following two choices
    
    # print difference 
    # (debug => checking what the value is)
    
    if difference == 0:
        result = "Player and computer tie!"
    elif difference == 1:
        result = "Player wins!"
    else:
        result = "Computer wins!"

    # convert comp_number to name using number_to_name
    computer_guess = num2name(comp_number)
    
    print "\nPlayer chooses", guess #guess by the user
    print "Computer chooses", computer_guess
    print result
      
valid = ['rock','paper','scissors']

while True:
    userChoice = str(raw_input('rock, paper, scissors or return to exit? '))
    if userChoice in valid:
        PaperScissorsRock(userChoice)
    else:
        print('Thanks for Playing')
        break

# testing
#PaperScissorsRock("rock")
#PaperScissorsRock("paper")
#PaperScissorsRock("scissors")

