name: Install SonarQube on Ubuntu
  hosts: sonarqube
  become: yes
  vars:
    sonar_version: "9.9.3.79811"   # LTS version (you can change if needed)
    sonar_user: "sonar"
    sonar_group: "sonar"
    sonar_install_dir: "/opt/sonarqube"
    postgres_db: "sonarqube"
    postgres_user: "sonar"
    postgres_password: "Admin123"
    sonar_version: 24.12.0.100206
    sonar_real_dir: "/opt/sonarqube-24.12.0.100206"
    sonar_install_dir: "/opt/sonarqube"

  tasks:

    - name: Ensure system is updated
      apt:
        update_cache: yes
        upgrade: yes

    - name: Install required packages
      apt:
        name:
          - openjdk-17-jdk
          - postgresql
          - postgresql-contrib
          - unzip
          - wget
        state: present

    - name: Ensure PostgreSQL is running
      service:
        name: postgresql
        state: started
        enabled: yes

    - name: Install psycopg2 dependency for Ansible PostgreSQL modules
      apt:
        name: python3-psycopg2
        state: present
        update_cache: yes

    - name: Ensure PostgreSQL user exists
      become: yes
      become_user: postgres
      postgresql_user:
        name: "{{ postgres_user }}"
        password: "{{ postgres_password }}"
        role_attr_flags: CREATEDB

    - name: Ensure PostgreSQL database exists
      become: yes
      become_user: postgres
      postgresql_db:
        name: "{{ postgres_db }}"
        owner: "{{ postgres_user }}"

    - name: Create sonar group
      group:
        name: "{{ sonar_group }}"
        state: present

    - name: Create sonar user
      user:
        name: "{{ sonar_user }}"
        group: "{{ sonar_group }}"
        create_home: yes
        shell: /bin/bash

    - name: Download SonarQube
      get_url:
        url: "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-24.12.0.100206.zip"
        dest: "/tmp/sonarqube.zip"
        mode: '0644'

    - name: Ensure SonarQube is extracted
      unarchive:
        src: "/tmp/sonarqube.zip"
        dest: /opt/
        remote_src: yes
        creates: "/opt/sonarqube-24.12.0.100206"

    - name: Find extracted SonarQube directory
      find:
        paths: /opt
        patterns: "sonarqube-*"
        file_type: directory
      register: found_sonarqube

    - name: Set fact for SonarQube directory
      set_fact:
        sonar_real_dir: "{{ found_sonarqube.files[0].path | default('/opt/sonarqube-24.12.0.100206') }}"

    - name: Create symlink for SonarQube
      file:
        src: "{{ sonar_real_dir }}"
        dest: /opt/sonarqube
        state: link
        force: yes

    - name: Create symlink to standard path
      file:
        src: "{{ sonar_real_dir }}"
        dest: "{{ sonar_install_dir }}"
        state: link
        force: yes

    - name: Change ownership of SonarQube directory
      file:
        path: "{{ sonar_real_dir }}"
        owner: "{{ sonar_user }}"
        group: "{{ sonar_group }}"
        recurse: yes

    - name: Configure SonarQube database settings
      lineinfile:
        path: "{{ sonar_install_dir }}/conf/sonar.properties"
        regexp: '^#?(sonar.jdbc.username|sonar.jdbc.password|sonar.jdbc.url)='
        line: "{{ item }}"
      loop:
        - "sonar.jdbc.username={{ postgres_user }}"
        - "sonar.jdbc.password={{ postgres_password }}"
        - "sonar.jdbc.url=jdbc:postgresql://localhost/{{ postgres_db }}"

    - name: Create systemd service file for SonarQube
      copy:
        dest: /etc/systemd/system/sonarqube.service
        content: |
          [Unit]
          Description=SonarQube service
          After=network.target postgresql.service

          [Service]
          Type=forking

          ExecStart={{ sonar_install_dir }}/bin/linux-x86-64/sonar.sh start
          ExecStop={{ sonar_install_dir }}/bin/linux-x86-64/sonar.sh stop

          User={{ sonar_user }}
          Group={{ sonar_group }}
          Restart=always
          LimitNOFILE=65536
          LimitNPROC=4096

          [Install]
          WantedBy=multi-user.target
        mode: '0644'

    - name: Reload systemd daemon
      command: systemctl daemon-reload

    - name: Enable SonarQube service
      service:
        name: sonarqube
        enabled: yes
        state: started

#after execution run the below commends from sonarqube
#sudo nano /opt/sonarqube-24.12.0.100206/conf/sonar.properties  ---> for config changes
#now make below commends to uncommed

#sonar.jdbc.username=sonar
#sonar.jdbc.password=your_password
#sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube

#now restart sonarqube

#sudo systemctl restart sonarqube
#sudo systemctl status sonarqube
#then install sonar-scanner
