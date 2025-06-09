# Hardware Tester
~~simple~~ lightweight hardware tester for Linux written in Bash. can run diagnostics on ram, cpu, ssd, and motherboard.

before installation, you must install the required libraries:
```
sudo apt update
sudo apt install sudo apt install stress stress-ng memtester fio dmidecode
```
note: you can install stress or stress-ng, whichever you prefer
## run
to run the script from the terminal, simply make the htest.sh file executable:
```
chmod +x ./htest.sh
./htest.sh
```
