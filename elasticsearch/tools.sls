{% from "elasticsearch/map.jinja" import elasticsearch_map with context %}
{% set initsystem = salt['grains.get']('init') %}

{% if 'curator' in elasticsearch_map.tools and elasticsearch_map.tools.curator.enabled %}

python-pip:
    pkg.installed:
        - name: {{ elasticsearch_map.pip_pkg }}

elasticsearch-curator:
    pip.installed:
        - name: elasticsearch-curator
        - require:
            - pkg: python-pip

{% endif %}

{% if 'cerebro' in elasticsearch_map.tools %}

{% if 'config' in elasticsearch_map.tools.cerebro %}
{% set cerebro_version = elasticsearch_map.tools.cerebro.config.version|default('0.8.1') %}
{% set cerebro_http_port = elasticsearch_map.tools.cerebro.config['http.port']|default('9000') %}
{% set cerebro_http_address = elasticsearch_map.tools.cerebro.config['http.address']|default('0.0.0.0') %}
{% else %}
{% set cerebro_version = '0.8.1' %}
{% set cerebro_http_port = '9000' %}
{% set cerebro_http_address = '0.0.0.0' %}
{% endif %}

elasticsearch-cerebro:
    cmd.run:
        - name: wget https://github.com/lmenezes/cerebro/releases/download/v{{ cerebro_version }}/cerebro-{{ cerebro_version }}.tgz -P /usr/src && tar xvf /usr/src/cerebro-{{ cerebro_version }}.tgz -C /opt/
        - unless: test -d /opt/cerebro-{{ cerebro_version }}

{% if initsystem == 'systemd' %}

elasticsearch-cerebro-unit:
    file.managed:
        - name: /usr/lib/systemd/system/cerebro.service
        - makedirs: True
        - user: root
        - group: root
        - mode: 644
        - contents: |
            [Unit]
            Description=Cerebro Monitoring Tool
            After=network.target
            Requires=network.target

            [Service]
            ExecStart=/opt/cerebro-{{ cerebro_version }}/bin/cerebro -Dhttp.port={{ cerebro_http_port }} -Dhttp.address={{ cerebro_http_address }}
            Restart=always

            [Install]
            WantedBy=multi-user.target
    module.run:
        - name: service.systemctl_reload
        - onchanges:
            - file: /usr/lib/systemd/system/cerebro.service
    service.running:
        - name: cerebro
    {% if elasticsearch_map.tools.cerebro.enabled %}
        - enable: True
    {% else %}
        - enable: False
    {% endif %}
        - reload: True

{% endif %}

{% endif %}
