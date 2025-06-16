# Saves syncronizer

Have you played online self served games with your friends? Generally this means there is only one guy who is serving the game. So you cannot simply start the server without your friend. Or else, maybe you sharing the save file manually so then the next one can take it and serve the game. Dont worry, got a better solution for you.


## How it works

- Creates a locker in the cloud.
- Checks local saves folder and cloud saves folder and replaces the local folder by the latest one.
- Opens the game and waits to detect game is closed.
- When game is closed it updates the cloud folder with the latest save.
- Releases the locker

## Requirements

- Google drive
- Steam games

## How to run

- Download google drive
- Create a google drive mirror folder
- Update the config.txt file with the right values
- Run always savesSyncronizer instead game launcher
