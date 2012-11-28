/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 6 and 7
// ASSIGNMENT 2
// CODE SKELETON
// TITLE: "LED Particle Simulation"
// Denis Ogun (do1303) & Josh Hargreaves (jh1288)
//
/////////////////////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <platform.h>

//Number of particles in the system
#define noParticles 4
//Whether to enable particle velocities
#define velocityFlag 0

/*
 * Port Definitions
 */

out port cled[4] = { PORT_CLOCKLED_0,
					 PORT_CLOCKLED_1,
					 PORT_CLOCKLED_2,
					 PORT_CLOCKLED_3 };

out port cledR = PORT_CLOCKLED_SELR;
in port buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

/*
 * Particle properties
 */

int positions[5] = {0, 3, 6, 9, 12};
int direction[5] = {-1, 1, -1, -1, -1};

typedef struct {
	int attempt;
	int position;
	int velocity;
} intention;


/*
 * Sorts the input user positions so that each LED has the correct neighbours
 *
 * @params:
 *              numbers[] - An array representing the numbers to be sorted
 *              array_size -  An integer representing the size of the array to be stored
 *
 * @operation:
 *              Performs the standard bubble sorting algorithm on a set of data
 */

void bubbleSort(unsigned int numbers[], int array_size)
{
  int i, j, temp;
  for (i = (array_size - 1); i > 0; i--)
  {
    for (j = 1; j <= i; j++)
    {
      if (numbers[j-1] > numbers[j])
      {
        temp = numbers[j-1];
        numbers[j-1] = numbers[j];
        numbers[j] = temp;
      }
    }
  }
}

/*
 * Displays an LED pattern in one quadrant of the LEDs
 *
 * @params:
 *              p - This represents the port with the LEDs we wish to control
 *              fromVisualiser -  A channel link to the visualiser process that controls the LEDs
 *
 * @operation:
 *              This process takes a port number of an LED to light up and lights it up. If the visualiser
 *              process sends a value of shutdown, then the showLED process is commanded to shutdown
 */

void showLED(out port p, chanend fromVisualiser) {
	unsigned int lightUpPattern;
	unsigned int running = 1;
	while (running) {
		select {
			case fromVisualiser :> lightUpPattern: //read LED pattern from visualiser process
				if(lightUpPattern != 100)
					p <: lightUpPattern; //send pattern to LEDs
				else
					running = 0;
				break;
			default:
				break;
		}
	}
}

/*
 * Process that controls the speaker on the board
 *
 * @params:
 *              wavelength - An integer value representing the pitch of the sound to play
 *              duration -  How long we wish to play the sound for
 *              speaker - A link to the output port that is connected to the speaker
 *
 * @operation:
 *              This process takes a pitch value and then plays a sound at that frequency on
 *              the speaker.
 *
 */

void playSound(unsigned int wavelength, int duration, out port speaker) {
	timer tmr;
	int t, isOn = 1;
	tmr :> t;
	for (int i=0; i<duration; i++) {
		isOn = !isOn;
		t += wavelength;
		tmr when timerafter(t) :> void;
		speaker <: isOn;
	}
}

/*
 * Acts as a timer to wait a certain amount of time before returning. Computes nothing of
 * any interest.
 *
 * @params:
 *              myTime - The length of time to pause a process for
 *
 * @operation:
 *              This process waits for a time period before continuing execution of the process.
 *
 */

void waitMoment(uint myTime) {
	timer tmr;
	unsigned int waitTime;
	tmr :> waitTime;
	waitTime += myTime;
	tmr when timerafter(waitTime) :> void;
}

/*
 * Process that controls which LEDs are lit up as well as interfacing with any button presses
 * that occur on the baard.
 *
 * @params:
 *              toButtons - A channel to the buttonListener process to get button presses
 *              show[] -  An array of channels that link the particles to the visualiser process
 *              toQuadrant[] - Channel links to the various LED quadrants on the XC-1A board.
 *              speaker - A link to the output port representing the speaker on the board.
 *
 * @operation:
 *              This process first takes the particle positions selected by the user and sends
 *              them to the particles.
 */

void visualiser(chanend toButtons, chanend show[], chanend toQuadrant[], out port speaker) {
	unsigned int display[noParticles]; //array of ant positions to be displayed, all values 0..11
	unsigned int running = 1; //helper variable to determine system shutdown
	int button;
	int paused = 0, reset = 0;
	int token = 1;//helper variable
	int noShutDown = 0, noPaused = 0;
	int restart = 0, setup = 1, position = 0, pressed = 1;
	cledR <: 1;
	//Reads in user selected particle positions, sorts them, and sends them to the particles
	for(int l = 0 ; l<noParticles; l++) {
		setup = 1;
		while(setup)
		{
			waitMoment(16000000);
			button = 0;
			select {
				case toButtons :> button:
					break;
				default:
					break;
			}
			//Moves a particle into position with B (clockwise) and C (anti-clockwise)
			//Pressing button A places a particle in a certain position
			if(button == 11) {
				position = (position + 11)%12;
				pressed = 1;
			} else if(button == 13) {
				pressed = 1;
				position = (position + 13)%12;
			} else if (button == 14) {
				if(pressed)
					setup = 0;
			}

			//Displays currently selected led as well as any
			//previously entered positions.
			if (position<12) display[l] = position;
			for (int i=0;i<4;i++) {
				button = 0;
				for (int k=0;k<=l;k++)
					button += (16<<(display[k]%3))*(display[k]/3==i);
				toQuadrant[i] <: button;
			}
		}
		position++;
		pressed = 0;
	}
	bubbleSort(display, noParticles);

	//Sends all the sorted user start positions to
	//the particles
	for(int i=0;i<noParticles;i++)
		show[i] <: display[i];

	while (running) {
		select {
			case toButtons :> button:
				//Tells the button listener, particles, and leds to shut down if 11 is pressed
				//Breaks out of loop so that the Visualiser is shut down. As the particles are
				//There are two different states the particles can be in when the button is preseed:
				//A paused state, and a normal running state. Token is passed to particles after
				//they have sent their position to the user, so setting token to zero tells the
				//particles to exit and finish the loop. 11 shuts everything down, 13 pauses, and 14
				//un-pauses.
				if(button == 11)
				{
					toButtons <: 0;
					if(!paused) {
						token = 0;
					} else {
						for(int i=0;i<noParticles;i++)
							show[i] <: 0;
						running = 0;
					}
				} else if (button == 13) {
					if(paused == 0)
					{
						paused = 1;
					}
				} else if (button == 14) {
					if(paused == 2)
						paused = 0;
					else if(paused == 1)
						paused = 2;
				}
				break;

			default:
				break;
		}
		for (int k=0;k<noParticles;k++) {
			select {
				//Only sends tokens to the user when the user has sent something to the particle
				//Thus making sure that we can't send something to the particle when it's trying
				//to send us something.
				case show[k] :> button:
					if (button < 12)
						display[k] = button;
					else
						playSound(20000,20,speaker);

					if(!paused)
						show[k] <: token;
					else {
						//This is to make sure that the visualiser keeps sending tokens to the particles
						//until all of them are pauseed.
						if(paused == 1) {
							noPaused++;
							show[k] <: 3;
						}
					}
					if(token == 0)
						noShutDown++;
					//Can only end the loop when all particles have been sent the shutdown token
					if(noShutDown == noParticles)
						running = 0;
					break;
				default:
					break;
			}
			//This means that the user has pressed start, and all of the 'pause' tokens
			//have finished sending to the particles, so the appropriate 'resume' tokens
			//are sent to the particles
			if((noPaused == noParticles) && (paused == 2))
			{
				for(int i=0;i<noParticles;i++)
					show[i] <: 4;
				noPaused = 0;
				paused = 0;
			}
		}
		//Light up the LEDs depending on the particle locations.
			for (int i=0;i<4;i++) {
				button = 0;
				for (int k=0;k<noParticles;k++)
					button += (16<<(display[k]%3))*(display[k]/3==i);
				toQuadrant[i] <: button;
			}
		}
	for (int i=0;i<4;i++)
		toQuadrant[i] <: 100;

	printf("Visualiser has exited\n");
}

/*
 * Process that passes button presses to the visualiser process
 *
 * @params:
 *              buttons - A link to the input port of the button that the user presses
 *              toVisualiser - A channel linking the button process to the visualiser process
 *              			   in order to send any button presses.
 *
 * @operation:
 *              This process checks that the game is still running from the visualiser process. If it is
 *              then we send any button presses to the visualiser process.
 */

void buttonListener(in port buttons, chanend toVisualiser) {
	int buttonInput; //button pattern currently pressed
	unsigned int running = 1; //helper variable to determine system shutdown
	while (running) {
		buttons when pinsneq(15) :> buttonInput;
		toVisualiser <: buttonInput;
		select {
			case toVisualiser :> running:
				break;
			default:
				break;
		}
	}
	printf("Buttons have exited\n");
}

/*
 * Process that represents a particle with the capabilities to talk to other particles to
 * the left and right of the current one.
 *
 * @params:
 *              left - A channel to the particle that is to the left of our particle
 *              right - A channel to the particle that is to the right of our particle
 *              toVisualiser - A channel to the visualiser process to send particle position
 *              			   updates so that the LED can be updated.
 *              startPosition - The position that a particle should start at based on which positions the user
 *              				has selected
 *              startDirection - The direciton that a particle should initially move in
 *              id - The ID of a specific particle. This is used to calculate the velocities of the particles.
 *
 * @operation:
 *              This process checks that the game is still running from the visualiser process. If it is
 *              then we send any button presses to the visualiser process.
 */

void particle(chanend left, chanend right, chanend toVisualiser, int startPosition, int startDirection, int id) {
	unsigned int moveCounter = 1; //overall no of moves performed by particle so far
	unsigned int position = startPosition; //the current particle position
	unsigned int attemptedPosition; //the next attempted position after considering move direction
	int currentDirection = startDirection; //the current direction the particle is moving
	int leftMoveForbidden = 0; //the verdict of the left neighbour if move is allowed
	int rightMoveForbidden = 0; //the verdict of the right neighbour if move is allowed
	int currentVelocity = 1; //the current particle velocity
	int currentPosition = startPosition;
	int leftAttempt, rightAttempt, j;
	int move = 0;
	int gameRunning = 1;
	int paused = 0;
	int once = 0;
	int directionChanged = 0;
	int temporaryCurrentPosition = currentPosition;
	intention leftIntent, rightIntent, temp;
	toVisualiser :> currentPosition;
	while(gameRunning)
	{
			temporaryCurrentPosition = currentPosition;
			directionChanged = 0;
			waitMoment(8000000*(1));
			attemptedPosition = ((currentPosition + currentDirection)+12)%12;
			//Particle number one sends out the attempt left
			if(id == 0){
				if(((moveCounter%(id+1)) == 0) || (velocityFlag)){
					rightIntent.velocity = id;
					rightIntent.position = temporaryCurrentPosition;
					rightIntent.attempt = attemptedPosition;
					left <: rightIntent;
					right <: rightIntent;
				} else {
					rightIntent.velocity = id;
					rightIntent.attempt = (currentPosition+13)%12;
					rightIntent.position = temporaryCurrentPosition;
					leftIntent.velocity = id;
					leftIntent.attempt = (currentPosition+11)%12;
					leftIntent.position = temporaryCurrentPosition;
					left <: leftIntent;
					right <: rightIntent;
				}
				left :> leftIntent;
				right :> rightIntent;

				//Receive any attempted moves from the particles to the left and right
				leftAttempt = leftIntent.attempt;
				rightAttempt = rightIntent.attempt;

				/* If another particle tries to move into our current position
				 * then we need to change our direction
				 */

				if((rightAttempt == currentPosition) && (currentDirection > 0))
				{
					directionChanged = 1;
					currentDirection = -currentDirection;
				}
				if((leftAttempt == currentPosition) && (currentDirection < 0))
				{
					currentDirection = -currentDirection;
					directionChanged = 1;
				}
				if((((moveCounter%(id+1)) == 0) || (velocityFlag)) && (directionChanged == 0) && (attemptedPosition != rightIntent.position)
						&& (attemptedPosition != leftIntent.position))

				/*This if statement does the following:
				 * 	1. Count the number of moves that a particle has made to allow for velocities
				 * 	2. Check that we have enabled velocities using the velocityFlag
				 * 	3. Check that during this move the particle hasn't already changed direction
				 */

				if(((moveCounter%(id+1)) == 0) || velocityFlag) && (directionChanged == 0))
				{
					currentPosition = (currentPosition + currentDirection +12)%12;
				}
			} else if(id == (noParticles-1)) {
				left :> leftIntent;
				right :> rightIntent;

				//Receive any attempted moves from the particles to the left and right
				leftAttempt  = leftIntent.attempt;
				rightAttempt = rightIntent.attempt;

				/* If another particle tries to move into our current position
				 * then we need to change our direction
				 */

				if((rightAttempt == currentPosition) && (currentDirection > 0))
				{
					currentDirection = -currentDirection;
					directionChanged = 1;
				}

				if((leftAttempt == currentPosition) && (currentDirection < 0))
				{
					currentDirection = -currentDirection;
					directionChanged = 1;
				}
				if((rightAttempt != attemptedPosition) && (leftAttempt != attemptedPosition) && ( (((moveCounter%(id+1)) == 0) || (velocityFlag))) && (directionChanged == 0)
						&&(attemptedPosition != rightIntent.position) && (attemptedPosition != leftIntent.position))

				/*This if statement checks:
				 * 	1. That there isn't an attempt from another channel (leftAttempt or rightAttempt) to the position we're attempting
				 * 	   to move into.
				 * 	2. Count the number of moves that a particle has made to allow for velocities
				 * 	3. Check that we have enabled velocities using the velocityFlag
				 * 	4. Check that during this move the particle hasn't already changed direction
				 */

				{
					currentPosition = (currentPosition + currentDirection +12)%12;
				}

				if(((moveCounter%(id+1)) == 0) || (velocityFlag)){
					rightIntent.velocity = id;
					rightIntent.position = temporaryCurrentPosition;
					rightIntent.attempt = attemptedPosition;
					left <: rightIntent;
					right <: rightIntent;
				} else {
					rightIntent.velocity = id;
					rightIntent.attempt = (currentPosition+13)%12;
					rightIntent.position = temporaryCurrentPosition;
					leftIntent.velocity = id;
					leftIntent.attempt = (currentPosition+11)%12;
					leftIntent.position = temporaryCurrentPosition;
					left <: leftIntent;
					right <: rightIntent;
				}
			} else {

				if(((moveCounter%(id+1)) == 0) || (velocityFlag)) {
					rightIntent.velocity = id;
					rightIntent.position = temporaryCurrentPosition;
					rightIntent.attempt = attemptedPosition;
					right <: rightIntent;
					left :> leftIntent;
					right :> temp;
					left <: rightIntent;
					rightIntent = temp;
				} else {
					rightIntent.velocity = id;
					rightIntent.attempt = (currentPosition+13)%12;
					rightIntent.position = temporaryCurrentPosition;
					leftIntent.velocity = id;
					leftIntent.attempt = (currentPosition+11)%12;
					leftIntent.position = temporaryCurrentPosition;
					right <: rightIntent;
					left :> temp;
					right :> rightIntent;
					left <: leftIntent;
					leftIntent = temp;
				}
				rightAttempt = rightIntent.attempt;
				leftAttempt = leftIntent.attempt;


				/* If another particle tries to move into our current position
				 * then we need to change our direction
				 */

				if((rightAttempt == currentPosition) && (currentDirection > 0))
				{
					currentDirection = -currentDirection;
					directionChanged = 1;
				}

				if((leftAttempt == currentPosition) && (currentDirection < 0))
				{
					currentDirection = -currentDirection;
					directionChanged = 1;
				}
				if((leftAttempt != attemptedPosition) && (((moveCounter%(id+1)) == 0) || velocityFlag) && (directionChanged == 0)
						&&(attemptedPosition != rightIntent.position) && (attemptedPosition != leftIntent.position))

				/* This if statement checks:
				 * 	1. That there isn't an attempt from another channel (leftAttempt) to the position we're attempting
				 * 	   to move into.
				 * 	2. Count the number of moves that a particle has made to allow for velocities
				 * 	3. Check that we have enabled velocities using the velocityFlag
				 * 	4. Check that during this move the particle hasn't already changed direction
				 */

				{
					//printf("id %d trying to move\n", id);
					currentPosition = (currentPosition + currentDirection +12)%12;
				}


			}
			toVisualiser <: currentPosition;
			//printf("id = %d, trying to move to %d\n", id, currentPosition);
			toVisualiser :> gameRunning;
			if(gameRunning == 3)
			{
				while(1)
				{
					toVisualiser :> gameRunning;
					if(gameRunning == 4 || gameRunning == 0)
						break;
				}
			}
			moveCounter++;
	}
	printf("Particle has exited\n");
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main(void) {
	chan quadrant[4]; //helper channels for LED visualisation
	chan show[noParticles]; //channels to link visualiser with particles
	chan neighbours[noParticles]; //channels to link neighbouring particles
	chan buttonToVisualiser; //channel to link buttons and visualiser
	//Main process
	par{
	//Button listener thread
		on stdcore[0]: buttonListener(buttons,buttonToVisualiser);
		//Visualiser thread
		on stdcore[0]: visualiser(buttonToVisualiser,show,quadrant,speaker);
		//Replicate the particle threads
		par (int k = 0; k<noParticles;k++) {
			on stdcore[k%4] : particle(neighbours[(k+(noParticles-1))%noParticles], neighbours[k], show[k], positions[k], direction[k], k);
		}
		//Replicate the threads performing LED visualisation
		par (int k=0;k<4;k++) {
			on stdcore[k%4]: showLED(cled[k],quadrant[k]);
		}
	}
	return 0;
}
