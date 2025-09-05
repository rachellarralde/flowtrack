// TimeTracker Pro - Main Application Logic

class TimeTracker {
    constructor() {
        this.data = {
            projects: [],
            workSessions: [],
            activeProject: null,
            currentTimer: {
                isRunning: false,
                startTime: null,
                elapsedTime: 0,
                sessionName: ""
            }
        };
        
        this.timerInterval = null;
        this.init();
    }

    init() {
        this.loadData();
        this.bindEvents();
        this.updateUI();
        this.updateTimerDisplay();
        
        // If timer was running when page was refreshed, restart interval
        if (this.data.currentTimer.isRunning && this.data.currentTimer.startTime) {
            this.resumeTimer();
        }
    }

    // Data Management
    loadData() {
        const savedData = localStorage.getItem('timetracker-data');
        if (savedData) {
            try {
                const parsed = JSON.parse(savedData);
                this.data = { ...this.data, ...parsed };
            } catch (e) {
                console.error('Error parsing saved data:', e);
            }
        }
    }

    saveData() {
        try {
            localStorage.setItem('timetracker-data', JSON.stringify(this.data));
        } catch (e) {
            console.error('Error saving data:', e);
        }
    }

    // Timer Functions
    startTimer() {
        if (!this.data.activeProject) {
            alert('Please select a project first');
            return;
        }

        const sessionName = document.getElementById('sessionName').value.trim();
        if (!sessionName) {
            alert('Please enter a session name');
            document.getElementById('sessionName').focus();
            return;
        }

        this.data.currentTimer.isRunning = true;
        this.data.currentTimer.startTime = Date.now() - this.data.currentTimer.elapsedTime;
        this.data.currentTimer.sessionName = sessionName;

        this.startTimerInterval();
        this.updateTimerControls();
        document.body.classList.add('timer-running');
        this.saveData();
    }

    startTimerInterval() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
        }
        
        this.timerInterval = setInterval(() => {
            if (this.data.currentTimer.isRunning && this.data.currentTimer.startTime) {
                this.updateTimerDisplay();
            }
        }, 1000);
    }

    resumeTimer() {
        if (this.data.currentTimer.startTime) {
            // Adjust start time to account for time elapsed while page was closed
            const now = Date.now();
            const expectedElapsed = now - this.data.currentTimer.startTime;
            this.data.currentTimer.startTime = now - expectedElapsed;
            
            this.startTimerInterval();
            document.body.classList.add('timer-running');
            this.updateTimerControls();
        }
    }

    pauseTimer() {
        if (!this.data.currentTimer.isRunning) return;

        this.data.currentTimer.isRunning = false;
        
        if (this.data.currentTimer.startTime) {
            this.data.currentTimer.elapsedTime = Date.now() - this.data.currentTimer.startTime;
        }
        
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }

        this.updateTimerControls();
        document.body.classList.remove('timer-running');
        this.saveData();
    }

    stopTimer() {
        if (this.data.currentTimer.elapsedTime === 0 && !this.data.currentTimer.isRunning) {
            return;
        }

        // Calculate final duration
        let finalDuration = this.data.currentTimer.elapsedTime;
        if (this.data.currentTimer.isRunning && this.data.currentTimer.startTime) {
            finalDuration = Date.now() - this.data.currentTimer.startTime;
        }

        // Only save if there's meaningful time recorded (at least 1 second)
        if (finalDuration >= 1000) {
            const session = {
                id: this.generateId(),
                projectId: this.data.activeProject,
                name: this.data.currentTimer.sessionName || 'Untitled Session',
                startTime: this.data.currentTimer.startTime || (Date.now() - finalDuration),
                endTime: Date.now(),
                duration: finalDuration
            };

            this.data.workSessions.push(session);
        }

        // Reset timer
        this.resetTimer();
        
        // Clear session name
        document.getElementById('sessionName').value = '';

        this.updateUI();
        this.saveData();
    }

    resetTimer() {
        this.data.currentTimer.isRunning = false;
        this.data.currentTimer.startTime = null;
        this.data.currentTimer.elapsedTime = 0;
        this.data.currentTimer.sessionName = "";

        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }

        document.body.classList.remove('timer-running');
        this.updateTimerDisplay();
        this.updateTimerControls();
        this.saveData();
    }

    updateTimerDisplay() {
        const timerDisplay = document.getElementById('timerDisplay');
        let displayTime = 0;

        if (this.data.currentTimer.isRunning && this.data.currentTimer.startTime) {
            displayTime = Date.now() - this.data.currentTimer.startTime;
        } else if (this.data.currentTimer.elapsedTime > 0) {
            displayTime = this.data.currentTimer.elapsedTime;
        }

        timerDisplay.textContent = this.formatTime(displayTime);
    }

    updateTimerControls() {
        const playBtn = document.getElementById('playPauseBtn');
        const stopBtn = document.getElementById('stopBtn');
        const resetBtn = document.getElementById('resetBtn');
        const sessionInput = document.getElementById('sessionName');

        const hasProject = this.data.activeProject !== null;
        const isRunning = this.data.currentTimer.isRunning;
        const hasTime = this.data.currentTimer.elapsedTime > 0 || isRunning;

        // Update play/pause button
        const playIcon = playBtn.querySelector('.play-icon');
        const playText = playBtn.querySelector('.play-text');
        
        if (isRunning) {
            playIcon.textContent = '⏸';
            playText.textContent = 'Pause';
        } else {
            playIcon.textContent = '▶';
            playText.textContent = 'Start';
        }

        // Enable/disable controls
        playBtn.disabled = !hasProject;
        stopBtn.disabled = !hasProject || (!isRunning && !hasTime);
        resetBtn.disabled = !hasProject || (!isRunning && !hasTime);
        sessionInput.disabled = !hasProject || isRunning;

        // Set session name if timer is running
        if (isRunning && this.data.currentTimer.sessionName && !sessionInput.value) {
            sessionInput.value = this.data.currentTimer.sessionName;
        }
    }

    // Project Management
    createProject(name) {
        const project = {
            id: this.generateId(),
            name: name.trim(),
            createdAt: Date.now()
        };

        this.data.projects.push(project);
        this.saveData();
        this.updateUI();
        return project;
    }

    selectProject(projectId) {
        this.data.activeProject = projectId;
        this.saveData();
        this.updateTimerControls();
    }

    getProjectSessions(projectId) {
        return this.data.workSessions.filter(session => session.projectId === projectId);
    }

    getProjectTotalTime(projectId) {
        const sessions = this.getProjectSessions(projectId);
        return sessions.reduce((total, session) => total + session.duration, 0);
    }

    deleteProject(projectId) {
        // Remove the project
        this.data.projects = this.data.projects.filter(project => project.id !== projectId);

        // Remove all work sessions for this project
        this.data.workSessions = this.data.workSessions.filter(session => session.projectId !== projectId);

        // If this was the active project, clear the selection
        if (this.data.activeProject === projectId) {
            this.data.activeProject = null;
            this.resetTimer();
        }

        this.saveData();
        this.updateUI();
        this.updateTimerControls();
    }

    openDeleteProjectModal(projectId) {
        const project = this.data.projects.find(p => p.id === projectId);
        if (!project) return;

        this.pendingDeleteProjectId = projectId;
        document.getElementById('deleteProjectName').textContent = project.name;
        this.openModal('deleteProjectModal');
    }

    // UI Updates
    updateUI() {
        this.updateProjectSelector();
        this.updateProjectsGrid();
    }

    updateProjectSelector() {
        const select = document.getElementById('projectSelect');
        select.innerHTML = '<option value="">Select Project</option>';

        this.data.projects.forEach(project => {
            const option = document.createElement('option');
            option.value = project.id;
            option.textContent = project.name;
            if (project.id === this.data.activeProject) {
                option.selected = true;
            }
            select.appendChild(option);
        });
    }

    updateProjectsGrid() {
        const grid = document.getElementById('projectsGrid');
        
        if (this.data.projects.length === 0) {
            grid.innerHTML = `
                <div class="empty-state">
                    <p>No projects yet. Create your first project to get started!</p>
                </div>
            `;
            return;
        }

        grid.innerHTML = '';

        this.data.projects.forEach(project => {
            const sessions = this.getProjectSessions(project.id);
            const totalTime = this.getProjectTotalTime(project.id);

            const card = document.createElement('div');
            card.className = 'project-card';
            card.innerHTML = `
                <div class="project-header">
                    <div class="project-name">${this.escapeHtml(project.name)}</div>
                    <button class="project-delete-btn" data-project-id="${project.id}" title="Delete project">
                        🗑️
                    </button>
                </div>
                <div class="project-stats">
                    <div class="project-time">${this.formatTime(totalTime)}</div>
                    <div class="project-sessions">${sessions.length} session${sessions.length !== 1 ? 's' : ''}</div>
                </div>
            `;

            // Add click handler for the card (but not the delete button)
            card.addEventListener('click', (e) => {
                if (!e.target.classList.contains('project-delete-btn')) {
                    this.openProjectModal(project.id);
                }
            });

            // Add click handler for the delete button
            const deleteBtn = card.querySelector('.project-delete-btn');
            deleteBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                this.openDeleteProjectModal(project.id);
            });

            grid.appendChild(card);
        });
    }

    // Modal Functions
    openProjectModal(projectId) {
        const project = this.data.projects.find(p => p.id === projectId);
        if (!project) return;

        const sessions = this.getProjectSessions(projectId);
        const totalTime = this.getProjectTotalTime(projectId);

        // Update modal content
        document.getElementById('modalProjectName').textContent = project.name;
        document.getElementById('modalTotalTime').textContent = this.formatTime(totalTime);
        document.getElementById('modalSessionCount').textContent = sessions.length;

        // Update sessions list
        const sessionsList = document.getElementById('sessionsList');
        
        if (sessions.length === 0) {
            sessionsList.innerHTML = '<p style="color: var(--color-text-secondary); text-align: center;">No sessions recorded yet.</p>';
        } else {
            sessionsList.innerHTML = '';
            
            sessions.sort((a, b) => b.startTime - a.startTime).forEach(session => {
                const sessionDiv = document.createElement('div');
                sessionDiv.className = 'session-item';
                sessionDiv.innerHTML = `
                    <div class="session-name">${this.escapeHtml(session.name)}</div>
                    <div class="session-details">
                        <div class="session-duration">${this.formatTime(session.duration)}</div>
                        <div class="session-date">${this.formatDate(session.startTime)}</div>
                    </div>
                `;
                sessionsList.appendChild(sessionDiv);
            });
        }

        // Show modal
        document.getElementById('projectModal').classList.remove('hidden');
    }

    closeModal(modalId) {
        document.getElementById(modalId).classList.add('hidden');
    }

    openModal(modalId) {
        document.getElementById(modalId).classList.remove('hidden');
    }

    openAddProjectModal() {
        document.getElementById('newProjectName').value = '';
        document.getElementById('addProjectModal').classList.remove('hidden');
        setTimeout(() => document.getElementById('newProjectName').focus(), 100);
    }

    // Event Bindings
    bindEvents() {
        // Timer controls
        document.getElementById('playPauseBtn').addEventListener('click', () => {
            if (this.data.currentTimer.isRunning) {
                this.pauseTimer();
            } else {
                this.startTimer();
            }
        });

        document.getElementById('stopBtn').addEventListener('click', () => {
            this.stopTimer();
        });

        document.getElementById('resetBtn').addEventListener('click', () => {
            if (confirm('Are you sure you want to reset the timer? Any unsaved time will be lost.')) {
                this.resetTimer();
            }
        });

        // Project selector
        document.getElementById('projectSelect').addEventListener('change', (e) => {
            this.selectProject(e.target.value || null);
        });

        // Add project button
        document.getElementById('addProjectBtn').addEventListener('click', () => {
            this.openAddProjectModal();
        });

        // Modal controls
        document.getElementById('closeModal').addEventListener('click', () => {
            this.closeModal('projectModal');
        });

        document.getElementById('closeAddProjectModal').addEventListener('click', () => {
            this.closeModal('addProjectModal');
        });

        document.getElementById('cancelAddProject').addEventListener('click', () => {
            this.closeModal('addProjectModal');
        });

        document.getElementById('confirmAddProject').addEventListener('click', () => {
            const name = document.getElementById('newProjectName').value.trim();
            if (name) {
                this.createProject(name);
                this.closeModal('addProjectModal');
            } else {
                alert('Please enter a project name');
                document.getElementById('newProjectName').focus();
            }
        });

        // Delete project modal controls
        document.getElementById('closeDeleteProjectModal').addEventListener('click', () => {
            this.closeModal('deleteProjectModal');
        });

        document.getElementById('cancelDeleteProject').addEventListener('click', () => {
            this.closeModal('deleteProjectModal');
        });

        document.getElementById('confirmDeleteProject').addEventListener('click', () => {
            const projectId = this.pendingDeleteProjectId;
            if (projectId) {
                this.deleteProject(projectId);
                this.closeModal('deleteProjectModal');
                this.pendingDeleteProjectId = null;
            }
        });

        // Modal backdrop clicks
        document.querySelectorAll('.modal-backdrop').forEach(backdrop => {
            backdrop.addEventListener('click', (e) => {
                if (e.target === backdrop) {
                    const modal = e.target.closest('.modal');
                    if (modal) {
                        modal.classList.add('hidden');
                    }
                }
            });
        });

        // Enter key for project name input
        document.getElementById('newProjectName').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                document.getElementById('confirmAddProject').click();
            }
        });

        // Enter key for session name input
        document.getElementById('sessionName').addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !this.data.currentTimer.isRunning && this.data.activeProject) {
                document.getElementById('playPauseBtn').click();
            }
        });

        // Handle page visibility changes to pause timer when tab is not active
        document.addEventListener('visibilitychange', () => {
            if (document.hidden && this.data.currentTimer.isRunning) {
                // Optionally pause timer when tab becomes hidden
                // this.pauseTimer();
            }
        });

        // Handle beforeunload to save state
        window.addEventListener('beforeunload', () => {
            this.saveData();
        });
    }

    // Utility Functions
    generateId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    }

    formatTime(milliseconds) {
        const totalSeconds = Math.floor(milliseconds / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;

        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }

    formatDate(timestamp) {
        const date = new Date(timestamp);
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const sessionDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());

        if (sessionDate.getTime() === today.getTime()) {
            return `Today ${date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
        } else if (sessionDate.getTime() === today.getTime() - 24 * 60 * 60 * 1000) {
            return `Yesterday ${date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
        } else {
            return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.timeTracker = new TimeTracker();
});