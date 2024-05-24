import pigpio
import time

# Constants
PWM_PIN = 12  # GPIO pin for PWM signal (BCM numbering)
PWM_FREQUENCY = 1000  # Frequency for PWM signal in Hz
MIN_DUTY_CYCLE = 50  # Minimum duty cycle (50%)
MAX_DUTY_CYCLE = 100  # Maximum duty cycle (100%)
STARTUP_DURATION = 5  # Startup duration in seconds
RUN_DURATION = 20  # Run duration before prompting again

# Initialize pigpio
pi = pigpio.pi()

if not pi.connected:
    exit()

def set_motor_power(level):
    # Convert power level (1-10) to duty cycle percentage
    duty_cycle = MIN_DUTY_CYCLE + (level - 1) * (MAX_DUTY_CYCLE - MIN_DUTY_CYCLE) / 9
    pi.set_PWM_dutycycle(PWM_PIN, duty_cycle * 2.55)  # Scale duty cycle to 0-255 for pigpio
    print(f"Motor power set to level {level} ({duty_cycle}%)")

def main():
    try:
        while True:
            # Prompt user to select power level
            power_level = int(input("Select a power level for the motor between 1 - 10: "))
            if power_level < 1 or power_level > 10:
                print("Invalid power level. Please select a level between 1 and 10.")
                continue
            
            # Initial startup period at 100% power
            print(f"Starting motor at {MAX_DUTY_CYCLE}% power for {STARTUP_DURATION} seconds...")
            pi.set_PWM_dutycycle(PWM_PIN, MAX_DUTY_CYCLE * 2.55)
            time.sleep(STARTUP_DURATION)
            
            # Set motor to selected power level
            set_motor_power(power_level)
            
            # Run motor at selected power level for specified duration
            time.sleep(RUN_DURATION)
            
            # Prompt user if they want to change the speed
            change_speed = input("Do you want to change the motor speed? (y/n): ").strip().lower()
            if change_speed != 'y':
                break
            
    except KeyboardInterrupt:
        print("Emergency stop triggered!")
        pi.set_PWM_dutycycle(PWM_PIN, 0)  # Turn off the motor
        print("Motor stopped.")

    finally:
        pi.set_PWM_dutycycle(PWM_PIN, 0)  # Ensure the motor is stopped
        pi.stop()

if __name__ == "__main__":
    main()
