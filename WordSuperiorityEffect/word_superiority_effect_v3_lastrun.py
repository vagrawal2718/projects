#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
This experiment was created using PsychoPy3 Experiment Builder (v2024.2.4),
    on April 01, 2025, at 12:14
If you publish work using this script the most relevant publication is:

    Peirce J, Gray JR, Simpson S, MacAskill M, Höchenberger R, Sogo H, Kastman E, Lindeløv JK. (2019) 
        PsychoPy2: Experiments in behavior made easy Behav Res 51: 195. 
        https://doi.org/10.3758/s13428-018-01193-y

"""

# --- Import packages ---
from psychopy import locale_setup
from psychopy import prefs
from psychopy import plugins
plugins.activatePlugins()
prefs.hardware['audioLib'] = 'ptb'
prefs.hardware['audioLatencyMode'] = '3'
from psychopy import sound, gui, visual, core, data, event, logging, clock, colors, layout, hardware
from psychopy.tools import environmenttools
from psychopy.constants import (NOT_STARTED, STARTED, PLAYING, PAUSED,
                                STOPPED, FINISHED, PRESSED, RELEASED, FOREVER, priority)

import numpy as np  # whole numpy lib is available, prepend 'np.'
from numpy import (sin, cos, tan, log, log10, pi, average,
                   sqrt, std, deg2rad, rad2deg, linspace, asarray)
from numpy.random import random, randint, normal, shuffle, choice as randchoice
import os  # handy system and path functions
import sys  # to get file system encoding

import psychopy.iohub as io
from psychopy.hardware import keyboard

# --- Setup global variables (available in all functions) ---
# create a device manager to handle hardware (keyboards, mice, mirophones, speakers, etc.)
deviceManager = hardware.DeviceManager()
# ensure that relative paths start from the same directory as this script
_thisDir = os.path.dirname(os.path.abspath(__file__))
# store info about the experiment session
psychopyVersion = '2024.2.4'
expName = 'word_superiority_effect_v3'  # from the Builder filename that created this script
# information about this experiment
expInfo = {
    'participant': f"{randint(0, 999999):06.0f}",
    'what is your first language?': 'English',
    'date|hid': data.getDateStr(),
    'expName|hid': expName,
    'psychopyVersion|hid': psychopyVersion,
}

# --- Define some variables which will change depending on pilot mode ---
'''
To run in pilot mode, either use the run/pilot toggle in Builder, Coder and Runner, 
or run the experiment with `--pilot` as an argument. To change what pilot 
#mode does, check out the 'Pilot mode' tab in preferences.
'''
# work out from system args whether we are running in pilot mode
PILOTING = core.setPilotModeFromArgs()
# start off with values from experiment settings
_fullScr = True
_winSize = [1536, 864]
# if in pilot mode, apply overrides according to preferences
if PILOTING:
    # force windowed mode
    if prefs.piloting['forceWindowed']:
        _fullScr = False
        # set window size
        _winSize = prefs.piloting['forcedWindowSize']

def showExpInfoDlg(expInfo):
    """
    Show participant info dialog.
    Parameters
    ==========
    expInfo : dict
        Information about this experiment.
    
    Returns
    ==========
    dict
        Information about this experiment.
    """
    # show participant info dialog
    dlg = gui.DlgFromDict(
        dictionary=expInfo, sortKeys=False, title=expName, alwaysOnTop=True
    )
    if dlg.OK == False:
        core.quit()  # user pressed cancel
    # return expInfo
    return expInfo


def setupData(expInfo, dataDir=None):
    """
    Make an ExperimentHandler to handle trials and saving.
    
    Parameters
    ==========
    expInfo : dict
        Information about this experiment, created by the `setupExpInfo` function.
    dataDir : Path, str or None
        Folder to save the data to, leave as None to create a folder in the current directory.    
    Returns
    ==========
    psychopy.data.ExperimentHandler
        Handler object for this experiment, contains the data to save and information about 
        where to save it to.
    """
    # remove dialog-specific syntax from expInfo
    for key, val in expInfo.copy().items():
        newKey, _ = data.utils.parsePipeSyntax(key)
        expInfo[newKey] = expInfo.pop(key)
    
    # data file name stem = absolute path + name; later add .psyexp, .csv, .log, etc
    if dataDir is None:
        dataDir = _thisDir
    filename = u'data/%s_%s_%s' % (expInfo['participant'], expName, expInfo['date'])
    # make sure filename is relative to dataDir
    if os.path.isabs(filename):
        dataDir = os.path.commonprefix([dataDir, filename])
        filename = os.path.relpath(filename, dataDir)
    
    # an ExperimentHandler isn't essential but helps with data saving
    thisExp = data.ExperimentHandler(
        name=expName, version='',
        extraInfo=expInfo, runtimeInfo=None,
        originPath='C:\\sem4_real\\IBC\\Experiment\\word_superiority_copy_v2\\word_superiority_effect_v3_lastrun.py',
        savePickle=True, saveWideText=True,
        dataFileName=dataDir + os.sep + filename, sortColumns='time'
    )
    thisExp.setPriority('thisRow.t', priority.CRITICAL)
    thisExp.setPriority('expName', priority.LOW)
    # return experiment handler
    return thisExp


def setupLogging(filename):
    """
    Setup a log file and tell it what level to log at.
    
    Parameters
    ==========
    filename : str or pathlib.Path
        Filename to save log file and data files as, doesn't need an extension.
    
    Returns
    ==========
    psychopy.logging.LogFile
        Text stream to receive inputs from the logging system.
    """
    # set how much information should be printed to the console / app
    if PILOTING:
        logging.console.setLevel(
            prefs.piloting['pilotConsoleLoggingLevel']
        )
    else:
        logging.console.setLevel('warning')
    # save a log file for detail verbose info
    logFile = logging.LogFile(filename+'.log')
    if PILOTING:
        logFile.setLevel(
            prefs.piloting['pilotLoggingLevel']
        )
    else:
        logFile.setLevel(
            logging.getLevel('exp')
        )
    
    return logFile


def setupWindow(expInfo=None, win=None):
    """
    Setup the Window
    
    Parameters
    ==========
    expInfo : dict
        Information about this experiment, created by the `setupExpInfo` function.
    win : psychopy.visual.Window
        Window to setup - leave as None to create a new window.
    
    Returns
    ==========
    psychopy.visual.Window
        Window in which to run this experiment.
    """
    if PILOTING:
        logging.debug('Fullscreen settings ignored as running in pilot mode.')
    
    if win is None:
        # if not given a window to setup, make one
        win = visual.Window(
            size=_winSize, fullscr=_fullScr, screen=0,
            winType='pyglet', allowGUI=False, allowStencil=True,
            monitor='testMonitor', color=[0,0,0], colorSpace='rgb',
            backgroundImage='', backgroundFit='none',
            blendMode='avg', useFBO=True,
            units='height',
            checkTiming=False  # we're going to do this ourselves in a moment
        )
    else:
        # if we have a window, just set the attributes which are safe to set
        win.color = [0,0,0]
        win.colorSpace = 'rgb'
        win.backgroundImage = ''
        win.backgroundFit = 'none'
        win.units = 'height'
    if expInfo is not None:
        # get/measure frame rate if not already in expInfo
        if win._monitorFrameRate is None:
            win._monitorFrameRate = win.getActualFrameRate(infoMsg='Attempting to measure frame rate of screen, please wait...')
        expInfo['frameRate'] = win._monitorFrameRate
    win.hideMessage()
    # show a visual indicator if we're in piloting mode
    if PILOTING and prefs.piloting['showPilotingIndicator']:
        win.showPilotingIndicator()
    
    return win


def setupDevices(expInfo, thisExp, win):
    """
    Setup whatever devices are available (mouse, keyboard, speaker, eyetracker, etc.) and add them to 
    the device manager (deviceManager)
    
    Parameters
    ==========
    expInfo : dict
        Information about this experiment, created by the `setupExpInfo` function.
    thisExp : psychopy.data.ExperimentHandler
        Handler object for this experiment, contains the data to save and information about 
        where to save it to.
    win : psychopy.visual.Window
        Window in which to run this experiment.
    Returns
    ==========
    bool
        True if completed successfully.
    """
    # --- Setup input devices ---
    ioConfig = {}
    
    # Setup iohub keyboard
    ioConfig['Keyboard'] = dict(use_keymap='psychopy')
    
    # Setup iohub experiment
    ioConfig['Experiment'] = dict(filename=thisExp.dataFileName)
    
    # Start ioHub server
    ioServer = io.launchHubServer(window=win, **ioConfig)
    
    # store ioServer object in the device manager
    deviceManager.ioServer = ioServer
    
    # create a default keyboard (e.g. to check for escape)
    if deviceManager.getDevice('defaultKeyboard') is None:
        deviceManager.addDevice(
            deviceClass='keyboard', deviceName='defaultKeyboard', backend='iohub'
        )
    if deviceManager.getDevice('start_resp') is None:
        # initialise start_resp
        start_resp = deviceManager.addDevice(
            deviceClass='keyboard',
            deviceName='start_resp',
        )
    if deviceManager.getDevice('key_resp') is None:
        # initialise key_resp
        key_resp = deviceManager.addDevice(
            deviceClass='keyboard',
            deviceName='key_resp',
        )
    # return True if completed successfully
    return True

def pauseExperiment(thisExp, win=None, timers=[], playbackComponents=[]):
    """
    Pause this experiment, preventing the flow from advancing to the next routine until resumed.
    
    Parameters
    ==========
    thisExp : psychopy.data.ExperimentHandler
        Handler object for this experiment, contains the data to save and information about 
        where to save it to.
    win : psychopy.visual.Window
        Window for this experiment.
    timers : list, tuple
        List of timers to reset once pausing is finished.
    playbackComponents : list, tuple
        List of any components with a `pause` method which need to be paused.
    """
    # if we are not paused, do nothing
    if thisExp.status != PAUSED:
        return
    
    # start a timer to figure out how long we're paused for
    pauseTimer = core.Clock()
    # pause any playback components
    for comp in playbackComponents:
        comp.pause()
    # make sure we have a keyboard
    defaultKeyboard = deviceManager.getDevice('defaultKeyboard')
    if defaultKeyboard is None:
        defaultKeyboard = deviceManager.addKeyboard(
            deviceClass='keyboard',
            deviceName='defaultKeyboard',
            backend='ioHub',
        )
    # run a while loop while we wait to unpause
    while thisExp.status == PAUSED:
        # check for quit (typically the Esc key)
        if defaultKeyboard.getKeys(keyList=['escape']):
            endExperiment(thisExp, win=win)
        # sleep 1ms so other threads can execute
        clock.time.sleep(0.001)
    # if stop was requested while paused, quit
    if thisExp.status == FINISHED:
        endExperiment(thisExp, win=win)
    # resume any playback components
    for comp in playbackComponents:
        comp.play()
    # reset any timers
    for timer in timers:
        timer.addTime(-pauseTimer.getTime())


def run(expInfo, thisExp, win, globalClock=None, thisSession=None):
    """
    Run the experiment flow.
    
    Parameters
    ==========
    expInfo : dict
        Information about this experiment, created by the `setupExpInfo` function.
    thisExp : psychopy.data.ExperimentHandler
        Handler object for this experiment, contains the data to save and information about 
        where to save it to.
    psychopy.visual.Window
        Window in which to run this experiment.
    globalClock : psychopy.core.clock.Clock or None
        Clock to get global time from - supply None to make a new one.
    thisSession : psychopy.session.Session or None
        Handle of the Session object this experiment is being run from, if any.
    """
    # mark experiment as started
    thisExp.status = STARTED
    # make sure window is set to foreground to prevent losing focus
    win.winHandle.activate()
    # make sure variables created by exec are available globally
    exec = environmenttools.setExecEnvironment(globals())
    # get device handles from dict of input devices
    ioServer = deviceManager.ioServer
    # get/create a default keyboard (e.g. to check for escape)
    defaultKeyboard = deviceManager.getDevice('defaultKeyboard')
    if defaultKeyboard is None:
        deviceManager.addDevice(
            deviceClass='keyboard', deviceName='defaultKeyboard', backend='ioHub'
        )
    eyetracker = deviceManager.getDevice('eyetracker')
    # make sure we're running in the directory for this experiment
    os.chdir(_thisDir)
    # get filename from ExperimentHandler for convenience
    filename = thisExp.dataFileName
    frameTolerance = 0.001  # how close to onset before 'same' frame
    endExpNow = False  # flag for 'escape' or other condition => quit the exp
    # get frame duration from frame rate in expInfo
    if 'frameRate' in expInfo and expInfo['frameRate'] is not None:
        frameDur = 1.0 / round(expInfo['frameRate'])
    else:
        frameDur = 1.0 / 60.0  # could not measure, so guess
    
    # Start Code - component code to be run after the window creation
    
    # --- Initialize components for Routine "instructions" ---
    background = visual.ImageStim(
        win=win,
        name='background', 
        image='bg.jpg', mask=None, anchor='center',
        ori=0.0, pos=(0, 0), draggable=False, size=(3, 3),
        color=[1,1,1], colorSpace='rgb', opacity=None,
        flipHoriz=False, flipVert=False,
        texRes=128.0, interpolate=True, depth=0.0)
    instruct_txt = visual.TextBox2(
         win, text='This fun game will show you a series of words. \nAfter each word you will be asked if that word contained a particular letter. \nUse the left and right arrow keys on the keyboard or click the onscreen buttons to answer the question:\n\nLeft Arrow = Yes\nRight Arrow = No\n\nPress Space key or Click on Start button to Start\n', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(0, 0), draggable=False,      letterHeight=0.04,
         size=(1, 1), borderWidth=2.0,
         color=[-1.0000, -1.0000, -1.0000], colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=None, borderColor=None,
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='instruct_txt',
         depth=-1, autoLog=True,
    )
    start_resp = keyboard.Keyboard(deviceName='start_resp')
    start = visual.TextBox2(
         win, text='START', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(0, -0.4), draggable=False,      letterHeight=0.05,
         size=(0.3, 0.1), borderWidth=2.0,
         color='white', colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=[-0.3333, -0.1608, -0.6314], borderColor='black',
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='start',
         depth=-3, autoLog=True,
    )
    start_mouse = event.Mouse(win=win)
    x, y = [None, None]
    start_mouse.mouseClock = core.Clock()
    
    # --- Initialize components for Routine "trial" ---
    background_2 = visual.ImageStim(
        win=win,
        name='background_2', 
        image='bg.jpg', mask=None, anchor='center',
        ori=0.0, pos=(0, 0), draggable=False, size=(3, 3),
        color=[1,1,1], colorSpace='rgb', opacity=None,
        flipHoriz=False, flipVert=False,
        texRes=128.0, interpolate=True, depth=0.0)
    fixation = visual.TextBox2(
         win, text='+', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(0, 0), draggable=False,      letterHeight=0.05,
         size=(0.5, 0.5), borderWidth=2.0,
         color=[-1.0000, -1.0000, -1.0000], colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=None, borderColor=None,
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='fixation',
         depth=-1, autoLog=True,
    )
    word = visual.TextBox2(
         win, text='', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(0, 0), draggable=False,      letterHeight=0.2,
         size=(0.7, 0.5), borderWidth=2.0,
         color=[-1.0000, -1.0000, -1.0000], colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=None, borderColor=None,
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='word',
         depth=-2, autoLog=True,
    )
    key_resp = keyboard.Keyboard(deviceName='key_resp')
    question = visual.TextBox2(
         win, text='Did the word contain the letter:', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(0, 0.3), draggable=False,      letterHeight=0.05,
         size=(0.5, 0.5), borderWidth=2.0,
         color=[-1.0000, -1.0000, -1.0000], colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=None, borderColor=None,
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='question',
         depth=-4, autoLog=True,
    )
    lefttxt = visual.TextBox2(
         win, text='YES', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(-0.3, -0.4), draggable=False,      letterHeight=0.05,
         size=(0.3, 0.1), borderWidth=2.0,
         color='white', colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=[-0.7333, 0.0902, -0.7333], borderColor='black',
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='lefttxt',
         depth=-5, autoLog=True,
    )
    righttxt = visual.TextBox2(
         win, text='NO', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(0.3, -0.4), draggable=False,      letterHeight=0.05,
         size=(0.3, 0.1), borderWidth=2.0,
         color='white', colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=[0.3961, -0.7333, -0.7333], borderColor='black',
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='righttxt',
         depth=-6, autoLog=True,
    )
    # Run 'Begin Experiment' code from track_score
    word_accuracies = []
    nonword_accuracies = []
    word_rts = []
    nonword_rts = []
    
    mouse = event.Mouse(win=win)
    x, y = [None, None]
    mouse.mouseClock = core.Clock()
    letter = visual.TextBox2(
         win, text='', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(0, 0), draggable=False,      letterHeight=0.2,
         size=(0.5, 0.5), borderWidth=2.0,
         color=[-1.0000, -1.0000, -1.0000], colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=None, borderColor=None,
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='letter',
         depth=-9, autoLog=True,
    )
    trialcount = visual.TextBox2(
         win, text='', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(0, .45), draggable=False,      letterHeight=0.05,
         size=(0.5, 0.5), borderWidth=2.0,
         color=[-1.0000, -1.0000, -1.0000], colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=None, borderColor=None,
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='trialcount',
         depth=-10, autoLog=True,
    )
    
    # --- Initialize components for Routine "end" ---
    background_3 = visual.ImageStim(
        win=win,
        name='background_3', 
        image='bg.jpg', mask=None, anchor='center',
        ori=0.0, pos=(0, 0), draggable=False, size=(3, 3),
        color=[1,1,1], colorSpace='rgb', opacity=None,
        flipHoriz=False, flipVert=False,
        texRes=128.0, interpolate=True, depth=0.0)
    fbtxt = visual.TextBox2(
         win, text='', placeholder='Type here...', font='Arial',
         ori=0.0, pos=(0, 0), draggable=False,      letterHeight=0.05,
         size=(1, 1), borderWidth=2.0,
         color=[-1.0000, -1.0000, -1.0000], colorSpace='rgb',
         opacity=None,
         bold=False, italic=False,
         lineSpacing=1.0, speechPoint=None,
         padding=0.0, alignment='center',
         anchor='center', overflow='visible',
         fillColor=None, borderColor=None,
         flipHoriz=False, flipVert=False, languageStyle='LTR',
         editable=False,
         name='fbtxt',
         depth=-2, autoLog=True,
    )
    
    # create some handy timers
    
    # global clock to track the time since experiment started
    if globalClock is None:
        # create a clock if not given one
        globalClock = core.Clock()
    if isinstance(globalClock, str):
        # if given a string, make a clock accoridng to it
        if globalClock == 'float':
            # get timestamps as a simple value
            globalClock = core.Clock(format='float')
        elif globalClock == 'iso':
            # get timestamps in ISO format
            globalClock = core.Clock(format='%Y-%m-%d_%H:%M:%S.%f%z')
        else:
            # get timestamps in a custom format
            globalClock = core.Clock(format=globalClock)
    if ioServer is not None:
        ioServer.syncClock(globalClock)
    logging.setDefaultClock(globalClock)
    # routine timer to track time remaining of each (possibly non-slip) routine
    routineTimer = core.Clock()
    win.flip()  # flip window to reset last flip timer
    # store the exact time the global clock started
    expInfo['expStart'] = data.getDateStr(
        format='%Y-%m-%d %Hh%M.%S.%f %z', fractionalSecondDigits=6
    )
    
    # --- Prepare to start Routine "instructions" ---
    # create an object to store info about Routine instructions
    instructions = data.Routine(
        name='instructions',
        components=[background, instruct_txt, start_resp, start, start_mouse],
    )
    instructions.status = NOT_STARTED
    continueRoutine = True
    # update component parameters for each repeat
    instruct_txt.reset()
    # create starting attributes for start_resp
    start_resp.keys = []
    start_resp.rt = []
    _start_resp_allKeys = []
    start.reset()
    # setup some python lists for storing info about the start_mouse
    start_mouse.x = []
    start_mouse.y = []
    start_mouse.leftButton = []
    start_mouse.midButton = []
    start_mouse.rightButton = []
    start_mouse.time = []
    start_mouse.clicked_name = []
    gotValidClick = False  # until a click is received
    # store start times for instructions
    instructions.tStartRefresh = win.getFutureFlipTime(clock=globalClock)
    instructions.tStart = globalClock.getTime(format='float')
    instructions.status = STARTED
    thisExp.addData('instructions.started', instructions.tStart)
    instructions.maxDuration = None
    # keep track of which components have finished
    instructionsComponents = instructions.components
    for thisComponent in instructions.components:
        thisComponent.tStart = None
        thisComponent.tStop = None
        thisComponent.tStartRefresh = None
        thisComponent.tStopRefresh = None
        if hasattr(thisComponent, 'status'):
            thisComponent.status = NOT_STARTED
    # reset timers
    t = 0
    _timeToFirstFrame = win.getFutureFlipTime(clock="now")
    frameN = -1
    
    # --- Run Routine "instructions" ---
    instructions.forceEnded = routineForceEnded = not continueRoutine
    while continueRoutine:
        # get current time
        t = routineTimer.getTime()
        tThisFlip = win.getFutureFlipTime(clock=routineTimer)
        tThisFlipGlobal = win.getFutureFlipTime(clock=None)
        frameN = frameN + 1  # number of completed frames (so 0 is the first frame)
        # update/draw components on each frame
        
        # *background* updates
        
        # if background is starting this frame...
        if background.status == NOT_STARTED and tThisFlip >= 0.0-frameTolerance:
            # keep track of start time/frame for later
            background.frameNStart = frameN  # exact frame index
            background.tStart = t  # local t and not account for scr refresh
            background.tStartRefresh = tThisFlipGlobal  # on global time
            win.timeOnFlip(background, 'tStartRefresh')  # time at next scr refresh
            # add timestamp to datafile
            thisExp.timestampOnFlip(win, 'background.started')
            # update status
            background.status = STARTED
            background.setAutoDraw(True)
        
        # if background is active this frame...
        if background.status == STARTED:
            # update params
            pass
        
        # *instruct_txt* updates
        
        # if instruct_txt is starting this frame...
        if instruct_txt.status == NOT_STARTED and tThisFlip >= 0.0-frameTolerance:
            # keep track of start time/frame for later
            instruct_txt.frameNStart = frameN  # exact frame index
            instruct_txt.tStart = t  # local t and not account for scr refresh
            instruct_txt.tStartRefresh = tThisFlipGlobal  # on global time
            win.timeOnFlip(instruct_txt, 'tStartRefresh')  # time at next scr refresh
            # add timestamp to datafile
            thisExp.timestampOnFlip(win, 'instruct_txt.started')
            # update status
            instruct_txt.status = STARTED
            instruct_txt.setAutoDraw(True)
        
        # if instruct_txt is active this frame...
        if instruct_txt.status == STARTED:
            # update params
            pass
        
        # *start_resp* updates
        waitOnFlip = False
        
        # if start_resp is starting this frame...
        if start_resp.status == NOT_STARTED and tThisFlip >= 0.0-frameTolerance:
            # keep track of start time/frame for later
            start_resp.frameNStart = frameN  # exact frame index
            start_resp.tStart = t  # local t and not account for scr refresh
            start_resp.tStartRefresh = tThisFlipGlobal  # on global time
            win.timeOnFlip(start_resp, 'tStartRefresh')  # time at next scr refresh
            # add timestamp to datafile
            thisExp.timestampOnFlip(win, 'start_resp.started')
            # update status
            start_resp.status = STARTED
            # keyboard checking is just starting
            waitOnFlip = True
            win.callOnFlip(start_resp.clock.reset)  # t=0 on next screen flip
            win.callOnFlip(start_resp.clearEvents, eventType='keyboard')  # clear events on next screen flip
        if start_resp.status == STARTED and not waitOnFlip:
            theseKeys = start_resp.getKeys(keyList=['space'], ignoreKeys=["escape"], waitRelease=False)
            _start_resp_allKeys.extend(theseKeys)
            if len(_start_resp_allKeys):
                start_resp.keys = _start_resp_allKeys[-1].name  # just the last key pressed
                start_resp.rt = _start_resp_allKeys[-1].rt
                start_resp.duration = _start_resp_allKeys[-1].duration
                # a response ends the routine
                continueRoutine = False
        
        # *start* updates
        
        # if start is starting this frame...
        if start.status == NOT_STARTED and tThisFlip >= 1-frameTolerance:
            # keep track of start time/frame for later
            start.frameNStart = frameN  # exact frame index
            start.tStart = t  # local t and not account for scr refresh
            start.tStartRefresh = tThisFlipGlobal  # on global time
            win.timeOnFlip(start, 'tStartRefresh')  # time at next scr refresh
            # add timestamp to datafile
            thisExp.timestampOnFlip(win, 'start.started')
            # update status
            start.status = STARTED
            start.setAutoDraw(True)
        
        # if start is active this frame...
        if start.status == STARTED:
            # update params
            pass
        # *start_mouse* updates
        
        # if start_mouse is starting this frame...
        if start_mouse.status == NOT_STARTED and t >= 1-frameTolerance:
            # keep track of start time/frame for later
            start_mouse.frameNStart = frameN  # exact frame index
            start_mouse.tStart = t  # local t and not account for scr refresh
            start_mouse.tStartRefresh = tThisFlipGlobal  # on global time
            win.timeOnFlip(start_mouse, 'tStartRefresh')  # time at next scr refresh
            # add timestamp to datafile
            thisExp.addData('start_mouse.started', t)
            # update status
            start_mouse.status = STARTED
            start_mouse.mouseClock.reset()
            prevButtonState = start_mouse.getPressed()  # if button is down already this ISN'T a new click
        if start_mouse.status == STARTED:  # only update if started and not finished!
            buttons = start_mouse.getPressed()
            if buttons != prevButtonState:  # button state changed?
                prevButtonState = buttons
                if sum(buttons) > 0:  # state changed to a new click
                    # check if the mouse was inside our 'clickable' objects
                    gotValidClick = False
                    clickableList = environmenttools.getFromNames(start, namespace=locals())
                    for obj in clickableList:
                        # is this object clicked on?
                        if obj.contains(start_mouse):
                            gotValidClick = True
                            start_mouse.clicked_name.append(obj.name)
                    if not gotValidClick:
                        start_mouse.clicked_name.append(None)
                    x, y = start_mouse.getPos()
                    start_mouse.x.append(x)
                    start_mouse.y.append(y)
                    buttons = start_mouse.getPressed()
                    start_mouse.leftButton.append(buttons[0])
                    start_mouse.midButton.append(buttons[1])
                    start_mouse.rightButton.append(buttons[2])
                    start_mouse.time.append(start_mouse.mouseClock.getTime())
                    if gotValidClick:
                        continueRoutine = False  # end routine on response
        
        # check for quit (typically the Esc key)
        if defaultKeyboard.getKeys(keyList=["escape"]):
            thisExp.status = FINISHED
        if thisExp.status == FINISHED or endExpNow:
            endExperiment(thisExp, win=win)
            return
        # pause experiment here if requested
        if thisExp.status == PAUSED:
            pauseExperiment(
                thisExp=thisExp, 
                win=win, 
                timers=[routineTimer], 
                playbackComponents=[]
            )
            # skip the frame we paused on
            continue
        
        # check if all components have finished
        if not continueRoutine:  # a component has requested a forced-end of Routine
            instructions.forceEnded = routineForceEnded = True
            break
        continueRoutine = False  # will revert to True if at least one component still running
        for thisComponent in instructions.components:
            if hasattr(thisComponent, "status") and thisComponent.status != FINISHED:
                continueRoutine = True
                break  # at least one component has not yet finished
        
        # refresh the screen
        if continueRoutine:  # don't flip if this routine is over or we'll get a blank screen
            win.flip()
    
    # --- Ending Routine "instructions" ---
    for thisComponent in instructions.components:
        if hasattr(thisComponent, "setAutoDraw"):
            thisComponent.setAutoDraw(False)
    # store stop times for instructions
    instructions.tStop = globalClock.getTime(format='float')
    instructions.tStopRefresh = tThisFlipGlobal
    thisExp.addData('instructions.stopped', instructions.tStop)
    # check responses
    if start_resp.keys in ['', [], None]:  # No response was made
        start_resp.keys = None
    thisExp.addData('start_resp.keys',start_resp.keys)
    if start_resp.keys != None:  # we had a response
        thisExp.addData('start_resp.rt', start_resp.rt)
        thisExp.addData('start_resp.duration', start_resp.duration)
    # store data for thisExp (ExperimentHandler)
    thisExp.addData('start_mouse.x', start_mouse.x)
    thisExp.addData('start_mouse.y', start_mouse.y)
    thisExp.addData('start_mouse.leftButton', start_mouse.leftButton)
    thisExp.addData('start_mouse.midButton', start_mouse.midButton)
    thisExp.addData('start_mouse.rightButton', start_mouse.rightButton)
    thisExp.addData('start_mouse.time', start_mouse.time)
    thisExp.addData('start_mouse.clicked_name', start_mouse.clicked_name)
    thisExp.nextEntry()
    # the Routine "instructions" was not non-slip safe, so reset the non-slip timer
    routineTimer.reset()
    
    # set up handler to look after randomisation of conditions etc
    trials = data.TrialHandler2(
        name='trials',
        nReps=1.0, 
        method='sequential', 
        extraInfo=expInfo, 
        originPath=-1, 
        trialList=data.importConditions('conditions3.xlsx'), 
        seed=None, 
    )
    thisExp.addLoop(trials)  # add the loop to the experiment
    thisTrial = trials.trialList[0]  # so we can initialise stimuli with some values
    # abbreviate parameter names if possible (e.g. rgb = thisTrial.rgb)
    if thisTrial != None:
        for paramName in thisTrial:
            globals()[paramName] = thisTrial[paramName]
    if thisSession is not None:
        # if running in a Session with a Liaison client, send data up to now
        thisSession.sendExperimentData()
    
    for thisTrial in trials:
        currentLoop = trials
        thisExp.timestampOnFlip(win, 'thisRow.t', format=globalClock.format)
        if thisSession is not None:
            # if running in a Session with a Liaison client, send data up to now
            thisSession.sendExperimentData()
        # abbreviate parameter names if possible (e.g. rgb = thisTrial.rgb)
        if thisTrial != None:
            for paramName in thisTrial:
                globals()[paramName] = thisTrial[paramName]
        
        # --- Prepare to start Routine "trial" ---
        # create an object to store info about Routine trial
        trial = data.Routine(
            name='trial',
            components=[background_2, fixation, word, key_resp, question, lefttxt, righttxt, mouse, letter, trialcount],
        )
        trial.status = NOT_STARTED
        continueRoutine = True
        # update component parameters for each repeat
        fixation.reset()
        word.reset()
        word.setText(this_word)
        # create starting attributes for key_resp
        key_resp.keys = []
        key_resp.rt = []
        _key_resp_allKeys = []
        question.reset()
        lefttxt.reset()
        righttxt.reset()
        # setup some python lists for storing info about the mouse
        mouse.x = []
        mouse.y = []
        mouse.leftButton = []
        mouse.midButton = []
        mouse.rightButton = []
        mouse.time = []
        mouse.clicked_name = []
        gotValidClick = False  # until a click is received
        letter.reset()
        letter.setText(critical_letter)
        trialcount.reset()
        trialcount.setText(str(trials.thisN) + '/' + str(trials.nTotal))
        # store start times for trial
        trial.tStartRefresh = win.getFutureFlipTime(clock=globalClock)
        trial.tStart = globalClock.getTime(format='float')
        trial.status = STARTED
        thisExp.addData('trial.started', trial.tStart)
        trial.maxDuration = None
        # keep track of which components have finished
        trialComponents = trial.components
        for thisComponent in trial.components:
            thisComponent.tStart = None
            thisComponent.tStop = None
            thisComponent.tStartRefresh = None
            thisComponent.tStopRefresh = None
            if hasattr(thisComponent, 'status'):
                thisComponent.status = NOT_STARTED
        # reset timers
        t = 0
        _timeToFirstFrame = win.getFutureFlipTime(clock="now")
        frameN = -1
        
        # --- Run Routine "trial" ---
        # if trial has changed, end Routine now
        if isinstance(trials, data.TrialHandler2) and thisTrial.thisN != trials.thisTrial.thisN:
            continueRoutine = False
        trial.forceEnded = routineForceEnded = not continueRoutine
        while continueRoutine:
            # get current time
            t = routineTimer.getTime()
            tThisFlip = win.getFutureFlipTime(clock=routineTimer)
            tThisFlipGlobal = win.getFutureFlipTime(clock=None)
            frameN = frameN + 1  # number of completed frames (so 0 is the first frame)
            # update/draw components on each frame
            
            # *background_2* updates
            
            # if background_2 is starting this frame...
            if background_2.status == NOT_STARTED and tThisFlip >= 0.0-frameTolerance:
                # keep track of start time/frame for later
                background_2.frameNStart = frameN  # exact frame index
                background_2.tStart = t  # local t and not account for scr refresh
                background_2.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(background_2, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.timestampOnFlip(win, 'background_2.started')
                # update status
                background_2.status = STARTED
                background_2.setAutoDraw(True)
            
            # if background_2 is active this frame...
            if background_2.status == STARTED:
                # update params
                pass
            
            # *fixation* updates
            
            # if fixation is starting this frame...
            if fixation.status == NOT_STARTED and tThisFlip >= 0.0-frameTolerance:
                # keep track of start time/frame for later
                fixation.frameNStart = frameN  # exact frame index
                fixation.tStart = t  # local t and not account for scr refresh
                fixation.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(fixation, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.timestampOnFlip(win, 'fixation.started')
                # update status
                fixation.status = STARTED
                fixation.setAutoDraw(True)
            
            # if fixation is active this frame...
            if fixation.status == STARTED:
                # update params
                pass
            
            # if fixation is stopping this frame...
            if fixation.status == STARTED:
                # is it time to stop? (based on global clock, using actual start)
                if tThisFlipGlobal > fixation.tStartRefresh + 0.5-frameTolerance:
                    # keep track of stop time/frame for later
                    fixation.tStop = t  # not accounting for scr refresh
                    fixation.tStopRefresh = tThisFlipGlobal  # on global time
                    fixation.frameNStop = frameN  # exact frame index
                    # add timestamp to datafile
                    thisExp.timestampOnFlip(win, 'fixation.stopped')
                    # update status
                    fixation.status = FINISHED
                    fixation.setAutoDraw(False)
            
            # *word* updates
            
            # if word is starting this frame...
            if word.status == NOT_STARTED and tThisFlip >= 0.5-frameTolerance:
                # keep track of start time/frame for later
                word.frameNStart = frameN  # exact frame index
                word.tStart = t  # local t and not account for scr refresh
                word.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(word, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.timestampOnFlip(win, 'word.started')
                # update status
                word.status = STARTED
                word.setAutoDraw(True)
            
            # if word is active this frame...
            if word.status == STARTED:
                # update params
                pass
            
            # if word is stopping this frame...
            if word.status == STARTED:
                # is it time to stop? (based on global clock, using actual start)
                if tThisFlipGlobal > word.tStartRefresh + 0.5-frameTolerance:
                    # keep track of stop time/frame for later
                    word.tStop = t  # not accounting for scr refresh
                    word.tStopRefresh = tThisFlipGlobal  # on global time
                    word.frameNStop = frameN  # exact frame index
                    # add timestamp to datafile
                    thisExp.timestampOnFlip(win, 'word.stopped')
                    # update status
                    word.status = FINISHED
                    word.setAutoDraw(False)
            
            # *key_resp* updates
            waitOnFlip = False
            
            # if key_resp is starting this frame...
            if key_resp.status == NOT_STARTED and tThisFlip >= 1-frameTolerance:
                # keep track of start time/frame for later
                key_resp.frameNStart = frameN  # exact frame index
                key_resp.tStart = t  # local t and not account for scr refresh
                key_resp.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(key_resp, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.timestampOnFlip(win, 'key_resp.started')
                # update status
                key_resp.status = STARTED
                # keyboard checking is just starting
                waitOnFlip = True
                win.callOnFlip(key_resp.clock.reset)  # t=0 on next screen flip
                win.callOnFlip(key_resp.clearEvents, eventType='keyboard')  # clear events on next screen flip
            if key_resp.status == STARTED and not waitOnFlip:
                theseKeys = key_resp.getKeys(keyList=['left','right'], ignoreKeys=["escape"], waitRelease=False)
                _key_resp_allKeys.extend(theseKeys)
                if len(_key_resp_allKeys):
                    key_resp.keys = _key_resp_allKeys[-1].name  # just the last key pressed
                    key_resp.rt = _key_resp_allKeys[-1].rt
                    key_resp.duration = _key_resp_allKeys[-1].duration
                    # was this correct?
                    if (key_resp.keys == str(corr_ans)) or (key_resp.keys == corr_ans):
                        key_resp.corr = 1
                    else:
                        key_resp.corr = 0
                    # a response ends the routine
                    continueRoutine = False
            
            # *question* updates
            
            # if question is starting this frame...
            if question.status == NOT_STARTED and tThisFlip >= 1-frameTolerance:
                # keep track of start time/frame for later
                question.frameNStart = frameN  # exact frame index
                question.tStart = t  # local t and not account for scr refresh
                question.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(question, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.timestampOnFlip(win, 'question.started')
                # update status
                question.status = STARTED
                question.setAutoDraw(True)
            
            # if question is active this frame...
            if question.status == STARTED:
                # update params
                pass
            
            # *lefttxt* updates
            
            # if lefttxt is starting this frame...
            if lefttxt.status == NOT_STARTED and tThisFlip >= 1-frameTolerance:
                # keep track of start time/frame for later
                lefttxt.frameNStart = frameN  # exact frame index
                lefttxt.tStart = t  # local t and not account for scr refresh
                lefttxt.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(lefttxt, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.timestampOnFlip(win, 'lefttxt.started')
                # update status
                lefttxt.status = STARTED
                lefttxt.setAutoDraw(True)
            
            # if lefttxt is active this frame...
            if lefttxt.status == STARTED:
                # update params
                pass
            
            # *righttxt* updates
            
            # if righttxt is starting this frame...
            if righttxt.status == NOT_STARTED and tThisFlip >= 1-frameTolerance:
                # keep track of start time/frame for later
                righttxt.frameNStart = frameN  # exact frame index
                righttxt.tStart = t  # local t and not account for scr refresh
                righttxt.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(righttxt, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.timestampOnFlip(win, 'righttxt.started')
                # update status
                righttxt.status = STARTED
                righttxt.setAutoDraw(True)
            
            # if righttxt is active this frame...
            if righttxt.status == STARTED:
                # update params
                pass
            # *mouse* updates
            
            # if mouse is starting this frame...
            if mouse.status == NOT_STARTED and t >= 1-frameTolerance:
                # keep track of start time/frame for later
                mouse.frameNStart = frameN  # exact frame index
                mouse.tStart = t  # local t and not account for scr refresh
                mouse.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(mouse, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.addData('mouse.started', t)
                # update status
                mouse.status = STARTED
                mouse.mouseClock.reset()
                prevButtonState = mouse.getPressed()  # if button is down already this ISN'T a new click
            if mouse.status == STARTED:  # only update if started and not finished!
                buttons = mouse.getPressed()
                if buttons != prevButtonState:  # button state changed?
                    prevButtonState = buttons
                    if sum(buttons) > 0:  # state changed to a new click
                        # check if the mouse was inside our 'clickable' objects
                        gotValidClick = False
                        clickableList = environmenttools.getFromNames([lefttxt, righttxt], namespace=locals())
                        for obj in clickableList:
                            # is this object clicked on?
                            if obj.contains(mouse):
                                gotValidClick = True
                                mouse.clicked_name.append(obj.name)
                                mouse.clicked_name.append(obj.name)
                        if gotValidClick:
                            x, y = mouse.getPos()
                            mouse.x.append(x)
                            mouse.y.append(y)
                            buttons = mouse.getPressed()
                            mouse.leftButton.append(buttons[0])
                            mouse.midButton.append(buttons[1])
                            mouse.rightButton.append(buttons[2])
                            mouse.time.append(mouse.mouseClock.getTime())
                        
                        continueRoutine = False  # end routine on response
            
            # *letter* updates
            
            # if letter is starting this frame...
            if letter.status == NOT_STARTED and tThisFlip >= 1-frameTolerance:
                # keep track of start time/frame for later
                letter.frameNStart = frameN  # exact frame index
                letter.tStart = t  # local t and not account for scr refresh
                letter.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(letter, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.timestampOnFlip(win, 'letter.started')
                # update status
                letter.status = STARTED
                letter.setAutoDraw(True)
            
            # if letter is active this frame...
            if letter.status == STARTED:
                # update params
                pass
            
            # *trialcount* updates
            
            # if trialcount is starting this frame...
            if trialcount.status == NOT_STARTED and tThisFlip >= 0-frameTolerance:
                # keep track of start time/frame for later
                trialcount.frameNStart = frameN  # exact frame index
                trialcount.tStart = t  # local t and not account for scr refresh
                trialcount.tStartRefresh = tThisFlipGlobal  # on global time
                win.timeOnFlip(trialcount, 'tStartRefresh')  # time at next scr refresh
                # add timestamp to datafile
                thisExp.timestampOnFlip(win, 'trialcount.started')
                # update status
                trialcount.status = STARTED
                trialcount.setAutoDraw(True)
            
            # if trialcount is active this frame...
            if trialcount.status == STARTED:
                # update params
                pass
            
            # check for quit (typically the Esc key)
            if defaultKeyboard.getKeys(keyList=["escape"]):
                thisExp.status = FINISHED
            if thisExp.status == FINISHED or endExpNow:
                endExperiment(thisExp, win=win)
                return
            # pause experiment here if requested
            if thisExp.status == PAUSED:
                pauseExperiment(
                    thisExp=thisExp, 
                    win=win, 
                    timers=[routineTimer], 
                    playbackComponents=[]
                )
                # skip the frame we paused on
                continue
            
            # check if all components have finished
            if not continueRoutine:  # a component has requested a forced-end of Routine
                trial.forceEnded = routineForceEnded = True
                break
            continueRoutine = False  # will revert to True if at least one component still running
            for thisComponent in trial.components:
                if hasattr(thisComponent, "status") and thisComponent.status != FINISHED:
                    continueRoutine = True
                    break  # at least one component has not yet finished
            
            # refresh the screen
            if continueRoutine:  # don't flip if this routine is over or we'll get a blank screen
                win.flip()
        
        # --- Ending Routine "trial" ---
        for thisComponent in trial.components:
            if hasattr(thisComponent, "setAutoDraw"):
                thisComponent.setAutoDraw(False)
        # store stop times for trial
        trial.tStop = globalClock.getTime(format='float')
        trial.tStopRefresh = tThisFlipGlobal
        thisExp.addData('trial.stopped', trial.tStop)
        # check responses
        if key_resp.keys in ['', [], None]:  # No response was made
            key_resp.keys = None
            # was no response the correct answer?!
            if str(corr_ans).lower() == 'none':
               key_resp.corr = 1;  # correct non-response
            else:
               key_resp.corr = 0;  # failed to respond (incorrectly)
        # store data for trials (TrialHandler)
        trials.addData('key_resp.keys',key_resp.keys)
        trials.addData('key_resp.corr', key_resp.corr)
        if key_resp.keys != None:  # we had a response
            trials.addData('key_resp.rt', key_resp.rt)
            trials.addData('key_resp.duration', key_resp.duration)
        # Run 'End Routine' code from track_score
        # --- Start of Corrected End Routine Code ---
        
        current_corr = 0 # Default to incorrect/no response
        current_rt = None # Default RT
        
        # Determine accuracy and RT based on response type (key or mouse) for the CURRENT trial
        if key_resp.keys: # Keyboard response was made
            current_corr = key_resp.corr # Use the already calculated correctness (0 or 1)
            current_rt = key_resp.rt
        elif mouse.clicked_name: # Mouse response was made (check if a clickable object name was stored)
            # Make sure mouse.clicked_name is not empty before accessing index 0
            if mouse.clicked_name: # Check list is not empty
                clicked_button = mouse.clicked_name[0] # 'lefttxt' or 'righttxt'
        
                # Determine correctness based on mouse click
                if clicked_button == 'lefttxt' and corr_ans == 'left':
                    current_corr = 1
                elif clicked_button == 'righttxt' and corr_ans == 'right':
                    current_corr = 1
                else:
                    current_corr = 0 # Clicked wrong button or non-clickable area if logic allows
        
                # Get RT (ensure mouse.time has values)
                if mouse.time:
                   current_rt = mouse.time[-1] # Get the time of the last click in this routine
            else:
                # Mouse was used, but no clickable object name recorded (e.g., clicked background)
                current_corr = 0
                if mouse.time:
                     current_rt = mouse.time[-1] # Still record RT if available
        
        else:
            # No valid response (neither key nor mouse click registered during response window)
            # key_resp.corr should already be 0 from earlier logic if applicable
            current_corr = 0 # Confirm incorrect
            current_rt = None # No RT
        
        # Now, append the CURRENT trial's data to the correct list for later averaging
        if condition == 'word':
            word_accuracies.append(current_corr)
            if current_rt is not None: # Only append RT if it exists
                word_rts.append(current_rt)
        elif condition == 'nonword':
            nonword_accuracies.append(current_corr)
            if current_rt is not None: # Only append RT if it exists
                nonword_rts.append(current_rt)
        
        # Add the data for the CURRENT trial to the output file
        thisExp.addData('correct', current_corr) # Save the accuracy of THIS trial
        thisExp.addData('rt', current_rt)           # Save the RT of THIS trial
        
        # --- End of Corrected End Routine Code ---
        # store data for trials (TrialHandler)
        trials.addData('mouse.x', mouse.x)
        trials.addData('mouse.y', mouse.y)
        trials.addData('mouse.leftButton', mouse.leftButton)
        trials.addData('mouse.midButton', mouse.midButton)
        trials.addData('mouse.rightButton', mouse.rightButton)
        trials.addData('mouse.time', mouse.time)
        trials.addData('mouse.clicked_name', mouse.clicked_name)
        # the Routine "trial" was not non-slip safe, so reset the non-slip timer
        routineTimer.reset()
        thisExp.nextEntry()
        
    # completed 1.0 repeats of 'trials'
    
    if thisSession is not None:
        # if running in a Session with a Liaison client, send data up to now
        thisSession.sendExperimentData()
    
    # --- Prepare to start Routine "end" ---
    # create an object to store info about Routine end
    end = data.Routine(
        name='end',
        components=[background_3, fbtxt],
    )
    end.status = NOT_STARTED
    continueRoutine = True
    # update component parameters for each repeat
    # Run 'Begin Routine' code from calculate
    # get averages
    word_acc = average(word_accuracies)
    nonword_acc = average(nonword_accuracies)
    word_rt = average(word_rts)
    nonword_rt = average(nonword_rts)
    
    # store to data file
    thisExp.addData('word_average_acc', word_acc)
    thisExp.addData('nonword_average_acc', nonword_acc)
    thisExp.addData('word_average_re', word_rt)
    thisExp.addData('nonword_average_rt', nonword_rt)
    
    # set up feedback text
    feedback = ''
    if word_acc > nonword_acc and word_rt < nonword_rt:
        feedback = 'You showed a word superiority effect!'
    if word_acc > nonword_acc and not word_rt < nonword_rt:
        feedback = 'You were more accurate for words versus non words, but you were faster for non words.'
    if word_rt < nonword_rt and not word_acc < nonword_acc:
        feedback = 'You were faster for words versus non words, but you were more accurate for non words.'
    if word_acc < nonword_acc and word_rt > nonword_rt:
        feedback = 'You showed the opposite of a word superiority effect - you were faster and more accurate for non words!'
    
    feedback += '\n Word accuracy: '
    feedback += str(int(word_acc*100))
    feedback += '%'
    feedback += '\n Word response time: '
    feedback += str(int(word_rt*1000))
    feedback += 'ms'
    feedback += '\n Non word accuracy: '
    feedback += str(int(nonword_acc*100))
    feedback += '%'
    feedback += '\n Non word response time: '
    feedback += str(int(nonword_rt*1000))
    feedback += 'ms'
    fbtxt.reset()
    fbtxt.setText(feedback)
    # store start times for end
    end.tStartRefresh = win.getFutureFlipTime(clock=globalClock)
    end.tStart = globalClock.getTime(format='float')
    end.status = STARTED
    thisExp.addData('end.started', end.tStart)
    end.maxDuration = None
    # keep track of which components have finished
    endComponents = end.components
    for thisComponent in end.components:
        thisComponent.tStart = None
        thisComponent.tStop = None
        thisComponent.tStartRefresh = None
        thisComponent.tStopRefresh = None
        if hasattr(thisComponent, 'status'):
            thisComponent.status = NOT_STARTED
    # reset timers
    t = 0
    _timeToFirstFrame = win.getFutureFlipTime(clock="now")
    frameN = -1
    
    # --- Run Routine "end" ---
    end.forceEnded = routineForceEnded = not continueRoutine
    while continueRoutine:
        # get current time
        t = routineTimer.getTime()
        tThisFlip = win.getFutureFlipTime(clock=routineTimer)
        tThisFlipGlobal = win.getFutureFlipTime(clock=None)
        frameN = frameN + 1  # number of completed frames (so 0 is the first frame)
        # update/draw components on each frame
        
        # *background_3* updates
        
        # if background_3 is starting this frame...
        if background_3.status == NOT_STARTED and tThisFlip >= 0.0-frameTolerance:
            # keep track of start time/frame for later
            background_3.frameNStart = frameN  # exact frame index
            background_3.tStart = t  # local t and not account for scr refresh
            background_3.tStartRefresh = tThisFlipGlobal  # on global time
            win.timeOnFlip(background_3, 'tStartRefresh')  # time at next scr refresh
            # add timestamp to datafile
            thisExp.timestampOnFlip(win, 'background_3.started')
            # update status
            background_3.status = STARTED
            background_3.setAutoDraw(True)
        
        # if background_3 is active this frame...
        if background_3.status == STARTED:
            # update params
            pass
        
        # *fbtxt* updates
        
        # if fbtxt is starting this frame...
        if fbtxt.status == NOT_STARTED and tThisFlip >= 0.0-frameTolerance:
            # keep track of start time/frame for later
            fbtxt.frameNStart = frameN  # exact frame index
            fbtxt.tStart = t  # local t and not account for scr refresh
            fbtxt.tStartRefresh = tThisFlipGlobal  # on global time
            win.timeOnFlip(fbtxt, 'tStartRefresh')  # time at next scr refresh
            # add timestamp to datafile
            thisExp.timestampOnFlip(win, 'fbtxt.started')
            # update status
            fbtxt.status = STARTED
            fbtxt.setAutoDraw(True)
        
        # if fbtxt is active this frame...
        if fbtxt.status == STARTED:
            # update params
            pass
        
        # check for quit (typically the Esc key)
        if defaultKeyboard.getKeys(keyList=["escape"]):
            thisExp.status = FINISHED
        if thisExp.status == FINISHED or endExpNow:
            endExperiment(thisExp, win=win)
            return
        # pause experiment here if requested
        if thisExp.status == PAUSED:
            pauseExperiment(
                thisExp=thisExp, 
                win=win, 
                timers=[routineTimer], 
                playbackComponents=[]
            )
            # skip the frame we paused on
            continue
        
        # check if all components have finished
        if not continueRoutine:  # a component has requested a forced-end of Routine
            end.forceEnded = routineForceEnded = True
            break
        continueRoutine = False  # will revert to True if at least one component still running
        for thisComponent in end.components:
            if hasattr(thisComponent, "status") and thisComponent.status != FINISHED:
                continueRoutine = True
                break  # at least one component has not yet finished
        
        # refresh the screen
        if continueRoutine:  # don't flip if this routine is over or we'll get a blank screen
            win.flip()
    
    # --- Ending Routine "end" ---
    for thisComponent in end.components:
        if hasattr(thisComponent, "setAutoDraw"):
            thisComponent.setAutoDraw(False)
    # store stop times for end
    end.tStop = globalClock.getTime(format='float')
    end.tStopRefresh = tThisFlipGlobal
    thisExp.addData('end.stopped', end.tStop)
    thisExp.nextEntry()
    # the Routine "end" was not non-slip safe, so reset the non-slip timer
    routineTimer.reset()
    
    # mark experiment as finished
    endExperiment(thisExp, win=win)


def saveData(thisExp):
    """
    Save data from this experiment
    
    Parameters
    ==========
    thisExp : psychopy.data.ExperimentHandler
        Handler object for this experiment, contains the data to save and information about 
        where to save it to.
    """
    filename = thisExp.dataFileName
    # these shouldn't be strictly necessary (should auto-save)
    thisExp.saveAsWideText(filename + '.csv', delim='auto')
    thisExp.saveAsPickle(filename)


def endExperiment(thisExp, win=None):
    """
    End this experiment, performing final shut down operations.
    
    This function does NOT close the window or end the Python process - use `quit` for this.
    
    Parameters
    ==========
    thisExp : psychopy.data.ExperimentHandler
        Handler object for this experiment, contains the data to save and information about 
        where to save it to.
    win : psychopy.visual.Window
        Window for this experiment.
    """
    if win is not None:
        # remove autodraw from all current components
        win.clearAutoDraw()
        # Flip one final time so any remaining win.callOnFlip() 
        # and win.timeOnFlip() tasks get executed
        win.flip()
    # return console logger level to WARNING
    logging.console.setLevel(logging.WARNING)
    # mark experiment handler as finished
    thisExp.status = FINISHED
    logging.flush()


def quit(thisExp, win=None, thisSession=None):
    """
    Fully quit, closing the window and ending the Python process.
    
    Parameters
    ==========
    win : psychopy.visual.Window
        Window to close.
    thisSession : psychopy.session.Session or None
        Handle of the Session object this experiment is being run from, if any.
    """
    thisExp.abort()  # or data files will save again on exit
    # make sure everything is closed down
    if win is not None:
        # Flip one final time so any remaining win.callOnFlip() 
        # and win.timeOnFlip() tasks get executed before quitting
        win.flip()
        win.close()
    logging.flush()
    if thisSession is not None:
        thisSession.stop()
    # terminate Python process
    core.quit()


# if running this experiment as a script...
if __name__ == '__main__':
    # call all functions in order
    expInfo = showExpInfoDlg(expInfo=expInfo)
    thisExp = setupData(expInfo=expInfo)
    logFile = setupLogging(filename=thisExp.dataFileName)
    win = setupWindow(expInfo=expInfo)
    setupDevices(expInfo=expInfo, thisExp=thisExp, win=win)
    run(
        expInfo=expInfo, 
        thisExp=thisExp, 
        win=win,
        globalClock='float'
    )
    saveData(thisExp=thisExp)
    quit(thisExp=thisExp, win=win)
