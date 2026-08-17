Antigravity.policy do
  allow :run_command, when: cmds(
    'git commit',
    'git status',
    'ls',
    'npm install',
    'git rev-parse',
    'mkdir',
    'docker ps',
    'git notes',
    'git branch',
  )
  allow :read_file, when: path('~/git/sre')
end
