/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 6 and 7
// ASSIGNMENT 2
// CODE SKELETON
// TITLE: "LED Particle Simulation"
//
/////////////////////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <platform.h>
out port cled[4] = {PORT_CLOCKLED_0,PORT_CLOCKLED_1,PORT_CLOCKLED_2,PORT_CLOCKLED_3};
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
in port buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;
#define noParticles 4 //overall number of particles threads in the system
int positions[5] = {0, 3, 6, 9, 12};
int direction[5] = {-1, 1, -1, -1, -1};
typedef struct {
	int position;
	int velocity;
} intent;
/////////////////////////////////////////////////////////////////////////////////////////
//
// Helper Functions provided for you
//
/////////////////////////////////////////////////////////////////////////////////////////
//DISPLAYS an LED pattern in one quadrant of the clock LEDs
void showLED(out port p, chanend fromVisualiser) {
	unsigned int lightUpPattern;
	unsigned int running = 1;
	while (running) {
		select {
			case fromVisualiser :> lightUpPattern: //read LED pattern from visualiser process
				p <: lightUpPattern; //send pattern to LEDs
				break;
			default:
				break;
		}
	}
}
//PLAYS a short sound (pls use with caution and consideration to other students in the labs!)
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
//WAIT function
void waitMoment(uint myTime) {
	timer tmr;
	unsigned int waitTime;
	tmr :> waitTime;
	waitTime += myTime;
	tmr when timerafter(waitTime) :> void;
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// RELEVANT PART OF CODE TO EXPAND
//
/////////////////////////////////////////////////////////////////////////////////////////
//PROCESS TO COORDINATE DISPLAY of LED Particles
void visualiser(chanend toButtons, chanend show[], chanend toQuadrant[], out port speaker) {
	unsigned int display[noParticles]; //array of ant positions to be displayed, all values 0..11
	unsigned int running = 1; //helper variable to determine system shutdown
	int j; //helper variable
	cledR <: 1;
	while (running) {
		for (int k=0;k<noParticles;k++) {
			select {
				case show[k] :> j:
					if (j<12) display[k] = j; else
					playSound(20000,20,speaker);
					break;
				case toButtons :> j:
					break;
			///////////////////////////////////////////////////////////////////////
			//
			// ADD YOUR CODE HERE TO ACT ON BUTTON INPUT
			//
			///////////////////////////////////////////////////////////////////////
				default:
					break;
			}
		//visualise particles
			for (int i=0;i<4;i++) {
				j = 0;
				for (int k=0;k<noParticles;k++)
					j += (16<<(display[k]%3))*(display[k]/3==i);
				toQuadrant[i] <: j;
			}
		}
	}
}
//READ BUTTONS and send commands to Visualiser
void buttonListener(in port buttons, chanend toVisualiser) {
	int buttonInput; //button pattern currently pressed
	unsigned int running = 1; //helper variable to determine system shutdown
	while (running) {
		buttons when pinsneq(15) :> buttonInput;
		///////////////////////////////////////////////////////////////////////
		//
		// ADD YOUR CODE HERE TO ACT ON BUTTON INPUT
		//
		///////////////////////////////////////////////////////////////////////
	}
}
//PARTICLE...thread to represent a particle - to be replicated noParticle-times
void particle(chanend left, chanend right, chanend toVisualiser, int startPosition, int startDirection, int id) {
	unsigned int moveCounter = 0; //overall no of moves performed by particle so far
	unsigned int position = startPosition; //the current particle position
	unsigned int attemptedPosition; //the next attempted position after considering move direction
	int currentDirection = startDirection; //the current direction the particle is moving
	int leftMoveForbidden = 0; //the verdict of the left neighbour if move is allowed
	int rightMoveForbidden = 0; //the verdict of the right neighbour if move is allowed
	int currentVelocity = 1; //the current particle velocity
	int currentPosition = startPosition;
	int leftAttempt, rightAttempt;
	intent attempt;
	toVisualiser <: startPosition;
	while(1)
	{
		waitMoment(8000000*2);
		attemptedPosition = ((currentPosition + currentDirection)+12)%12;
		if(id == 0){
			left <: attemptedPosition;
			right <: attemptedPosition;
			left :> leftAttempt;
			right :> rightAttempt;
			//printf("%d %d %d\n", leftAttempt, rightAttempt, attemptedPosition);
			if((rightAttempt == currentPosition) || (leftAttempt == currentPosition)
					|| (rightAttempt == attemptedPosition) || leftAttempt == attemptedPosition)
			{
				currentDirection = -currentDirection;
				//printf("Changed Direction\n");
			}
			currentPosition = (currentPosition + currentDirection +12)%12;
		} else if(id == (noParticles-1)) {
			left :> leftAttempt;
			right :> rightAttempt;
			if((rightAttempt == currentPosition) || (leftAttempt == currentPosition)
								|| (rightAttempt == attemptedPosition) || leftAttempt == attemptedPosition) {
				currentDirection = -currentDirection;
			}
			currentPosition = (currentPosition + currentDirection +12)%12;
			//attemptedPosition = ((currentPosition + currentDirection)+12)%12;
			left <: attemptedPosition;
			right <: attemptedPosition;
		} else {
			right <: attemptedPosition;
			left :> leftAttempt;
			right :> rightAttempt;
			left <: attemptedPosition;
			if((rightAttempt == currentPosition) || (leftAttempt == currentPosition)
								|| (rightAttempt == attemptedPosition) || leftAttempt == attemptedPosition) {
				//printf("Changed Direction\n");
				currentDirection = -currentDirection;
			}
			currentPosition = (currentPosition + currentDirection +12)%12;
		}
		//currentPosition = attemptedPosition;
		toVisualiser <: currentPosition;
	}
///////////////////////////////////////////////////////////////////////
//
// ADD YOUR CODE HERE TO SIMULATE PARTICLE BEHAVIOUR
//
///////////////////////////////////////////////////////////////////////
}
//MAIN PROCESS defining channels, orchestrating and starting the threads
int main(void) {
	chan quadrant[4]; //helper channels for LED visualisation
	chan show[noParticles]; //channels to link visualiser with particles
	chan neighbours[noParticles]; //channels to link neighbouring particles
	chan buttonToVisualiser; //channel to link buttons and visualiser
	//MAIN PROCESS HARNESS
	par{
	//BUTTON LISTENER THREAD
		on stdcore[0]: buttonListener(buttons,buttonToVisualiser);
		///////////////////////////////////////////////////////////////////////
		//
		// ADD YOUR CODE HERE TO REPLICATE PARTICLE THREADS particle(�)
		//
		///////////////////////////////////////////////////////////////////////
		//VISUALISER THREAD
		par (int k = 0; k<noParticles;k++) {
			on stdcore[k%4] : particle(neighbours[(k+(noParticles-1))%noParticles], neighbours[k], show[k], positions[k], direction[k], k);
		}
		/*on stdcore[0] : particle(neighbours[2], neighbours[0], show[0], positions[0], direction[0], 0);
		on stdcore[1] : particle(neighbours[0], neighbours[1], show[1], positions[1], direction[1], 1);
		on stdcore[2] : particle(neighbours[1], neighbours[2], show[2], positions[2], direction[2], 2);*/
		on stdcore[0]: visualiser(buttonToVisualiser,show,quadrant,speaker);
		//REPLICATION FOR THREADS PERFORMING LED VISUALISATION
		par (int k=0;k<4;k++) {
			on stdcore[k%4]: showLED(cled[k],quadrant[k]);
		}
	}
	return 0;
}
