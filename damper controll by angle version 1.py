import sys
import time
from qwiic_relay import QwiicRelay

# Constants
I2C_ADDRESS = 0x0A  # The I2C address for the Qwiic Relay
FULLY_OPEN_TIME = 55  # Time in seconds to fully open the damper from 0 to 90 degrees
MAX_ANGLE = 90  # Maximum angle the damper can open to
RESET_TIME = 57  # Time in seconds to close the damper completely

# Helper functions
def calculate_time_to_move(current_angle, target_angle):
    """
    Calculate the time needed to move from the current angle to the target angle.
    This is a proportion of the full opening time based on the angle difference.
    """
    angle_diff = abs(target_angle - current_angle)  # Calculate the difference in angles
    return (angle_diff / MAX_ANGLE) * FULLY_OPEN_TIME  # Proportion of the full time

# Main class to control the damper
class DamperController:
    def __init__(self, i2c_address):
        """
        Initialize the DamperController with the specified I2C address.
        """
        self.i2c_address = i2c_address  # Store the I2C address
        self.relay = QwiicRelay(i2c_address)  # Initialize the Qwiic Relay

        # Check if the relay is connected properly
        if self.relay.begin() == False:
            print("The Qwiic Relay isn't connected to the system. Please check your connection", file=sys.stderr)
            sys.exit(1)  # Exit the program if the relay is not connected

        self.current_angle = 0  # Start with the damper fully closed
        self.adjustment_count = 0  # Counter for the number of adjustments

    def move_damper_to_angle(self, target_angle):
        """
        Move the damper to the specified target angle.
        """
        # Validate the target angle
        if target_angle < 0 or target_angle > MAX_ANGLE:
            raise ValueError("Target angle must be between 0 and 90 degrees.")

        # If the target angle is the same as the current angle, do nothing
        if target_angle == self.current_angle:
            print("Damper is already at the target angle.")
            return

        # Calculate the time required to move to the target angle
        time_to_move = calculate_time_to_move(self.current_angle, target_angle)

        # Determine the direction of movement and activate the corresponding relay
        if target_angle > self.current_angle:
            # Open the damper
            self.relay.set_relay_on(1)  # Turn on relay 1 to open the damper
            print(f"Opening damper from {self.current_angle}° to {target_angle}°")
        else:
            # Close the damper
            self.relay.set_relay_on(2)  # Turn on relay 2 to close the damper
            print(f"Closing damper from {self.current_angle}° to {target_angle}°")

        # Wait for the damper to move to the target angle
        time.sleep(time_to_move)

        # Turn off both relays after the move

        self.relay.set_relay_off(1)  # Turn off relay 1
        self.relay.set_relay_off(2)  # Turn off relay 2

        # Update the current angle to the target angle
        self.current_angle = target_angle
        print(f"Damper is now at {self.current_angle}°")

        # Increment the adjustment counter
        self.adjustment_count += 1
        print(f"Adjustment count: {self.adjustment_count}")

        # Reset the damper if the adjustment count reaches 20
        if self.adjustment_count >= 20:
            self.reset_damper()

    def reset_damper(self):
        """
        Reset the damper by closing it all the way.
        """
        print("Resetting the damper...")
        self.relay.set_relay_on(2)  # Turn on relay 2 to close the damper completely
        time.sleep(RESET_TIME)  # Wait for 57 seconds to ensure it's fully closed
        self.relay.set_relay_off(2)  # Turn off relay 2

        # Update the current angle and reset the adjustment counter
        self.current_angle = 0
        self.adjustment_count = 0
        print("Damper has been reset to 0° and adjustment count has been reset.")

# Example function to run the damper control example
def runExample():
    """
    Run an example of the damper control system, allowing the user to input target angles.
    """
    print("\nSparkFun Qwiic Relay Example\n")

    # Initialize the DamperController
    damper_controller = DamperController(I2C_ADDRESS)

    try:
        while True:
            try:
                # Prompt the user for a target angle
                target_angle = float(input("Enter the target angle for the damper (0 to 90 degrees, or -1 to exit): >

                # Exit the loop if the user enters -1
                if target_angle == -1:
                    print("Exiting...")
                    break

                # Move the damper to the specified target angle
                damper_controller.move_damper_to_angle(target_angle)
            except ValueError as e:
                # Handle invalid input
                print(f"Invalid input: {e}. Please enter a valid angle or -1 to exit.")
    except KeyboardInterrupt:
        # Gracefully handle a keyboard interrupt (Ctrl+C)
# Wait for the damper to move to the target angle
        time.sleep(time_to_move)

        # Turn off both relays after the move
        self.relay.set_relay_off(1)  # Turn off relay 1
        self.relay.set_relay_off(2)  # Turn off relay 2

        # Update the current angle to the target angle
        self.current_angle = target_angle
        print(f"Damper is now at {self.current_angle}°")

        # Increment the adjustment counter
        self.adjustment_count += 1
        print(f"Adjustment count: {self.adjustment_count}")

        # Reset the damper if the adjustment count reaches 20
        if self.adjustment_count >= 20:
            self.reset_damper()

    def reset_damper(self):
        """
        Reset the damper by closing it all the way.
        """
        print("Resetting the damper...")
        self.relay.set_relay_on(2)  # Turn on relay 2 to close the damper completely
        time.sleep(RESET_TIME)  # Wait for 57 seconds to ensure it's fully closed
        self.relay.set_relay_off(2)  # Turn off relay 2

        # Update the current angle and reset the adjustment counter
        self.current_angle = 0
        self.adjustment_count = 0
        print("Damper has been reset to 0° and adjustment count has been reset.")

# Example function to run the damper control example
def runExample():
    """
    Run an example of the damper control system, allowing the user to input target angles.
    """
    print("\nSparkFun Qwiic Relay Example\n")

    # Initialize the DamperController
    damper_controller = DamperController(I2C_ADDRESS)

    try:
        while True:
            try:
                # Prompt the user for a target angle
                target_angle = float(input("Enter the target angle for the damper (0 to 90 degrees, or -1 to exit): >

                # Exit the loop if the user enters -1
                if target_angle == -1:
                    print("Exiting...")
                    break

                # Move the damper to the specified target angle
                damper_controller.move_damper_to_angle(target_angle)
            except ValueError as e:
                # Handle invalid input
                print(f"Invalid input: {e}. Please enter a valid angle or -1 to exit.")
    except KeyboardInterrupt:
        # Handle a keyboard interrupt (Ctrl+C)
        print("\nProgram interrupted. Turning off both relays...")
        print("\nProgram interrupted. Turning off both relays...")
        # Turn off both relays
        damper_controller.relay.set_relay_off(1)
        damper_controller.relay.set_relay_off(2)
        print("Relays turned off. Exiting...")

# Ensure the example runs only when the script is executed directly
if __name__ == '__main__':
    runExample()
