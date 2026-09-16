Nếu nhìn theo góc độ **Senior DevOps giải thích cho Fresher**, thì sau khi developer **build một app**, một hệ thống DevOps hoàn chỉnh thường không chỉ có Docker/Jenkins, mà là cả một **pipeline từ code → build → test → deploy → monitor → alert**.

## 1. Bức tranh tổng thể

```text
Developer
   │
   ▼
Git Repository
(GitHub / GitLab)
   │
   ▼
CI/CD
(Jenkins / GitLab CI / GitHub Actions)
   │
   ├── 1. Build
   ├── 2. Unit Test
   ├── 3. Code Quality
   ├── 4. Security Scan
   ├── 5. Build Docker Image
   └── 6. Push Image
            │
            ▼
      Container Registry
      (Docker Hub / ECR / Nexus)
            │
            ▼
      Deployment
      ├── Docker Compose
      ├── Kubernetes
      └── Helm
            │
            ▼
       Application
            │
      ┌─────┴─────┐
      ▼           ▼
   Database     Redis/Kafka
      │
      ▼
 Monitoring
 ├── Prometheus
 ├── Grafana
 └── Alertmanager

Logging
 ├── Elasticsearch
 ├── Logstash
 └── Kibana
```

Nói đơn giản:

> **Dev viết code → Git lưu code → CI/CD kiểm tra & build → Docker đóng gói → Registry lưu image → Server/Kubernetes chạy app → Monitoring/Logging theo dõi app.**

---

# 2. Sau khi build app thì có những thành phần gì?

Có thể chia thành **8 nhóm chính**.

| Nhóm           | Công cụ thường gặp                 | Vai trò                   |
| -------------- | ---------------------------------- | ------------------------- |
| Source Control | Git, GitHub, GitLab                | Lưu source code           |
| CI/CD          | Jenkins, GitLab CI, GitHub Actions | Tự động build/test/deploy |
| Build          | Maven, Gradle, npm, pip            | Build application         |
| Container      | Docker                             | Đóng gói application      |
| Registry       | Docker Hub, Nexus, ECR             | Lưu Docker image          |
| Deployment     | Kubernetes, Docker Compose, Helm   | Chạy application          |
| Monitoring     | Prometheus, Grafana                | Theo dõi hệ thống         |
| Logging        | ELK, Loki                          | Thu thập & tìm kiếm log   |

Ngoài ra còn có:

* Database
* Redis
* Kafka
* Load Balancer
* API Gateway
* Secrets Management
* Security Scanner
* Cloud Infrastructure
* Backup

---

# 3. Git — nơi chứa source code

Ví dụ:

```text
GitHub
   │
   ├── backend/
   ├── frontend/
   ├── Dockerfile
   ├── pom.xml
   └── README.md
```

Developer code xong:

```bash
git add .
git commit -m "add login"
git push
```

Sau khi `push`, CI/CD có thể được trigger.

Ví dụ:

```text
Developer
   │
   │ git push
   ▼
GitHub
   │
   │ webhook
   ▼
Jenkins
```

---

# 4. CI/CD — trung tâm tự động hóa

Đây là phần rất quan trọng.

Ví dụ dùng **Jenkins**.

Jenkins nhận code mới và thực hiện:

```text
Checkout
   ↓
Build
   ↓
Unit Test
   ↓
SonarQube
   ↓
Security Scan
   ↓
Docker Build
   ↓
Docker Push
   ↓
Deploy
```

Ví dụ backend Java:

```bash
mvn clean package
```

Sau đó:

```bash
docker build -t my-app:1.0 .
```

Push:

```bash
docker push myrepo/my-app:1.0
```

Deploy:

```bash
kubectl apply -f deployment.yaml
```

---

# 5. Docker — đóng gói app

Docker giải quyết vấn đề:

> "Máy tôi chạy được nhưng server không chạy."

Ví dụ Spring Boot:

```text
Application
   +
Java
   +
Dependencies
   +
Configuration
        │
        ▼
   Docker Image
```

Dockerfile:

```dockerfile
FROM eclipse-temurin:21

COPY target/app.jar app.jar

ENTRYPOINT ["java", "-jar", "app.jar"]
```

Build:

```bash
docker build -t my-app:1.0 .
```

Kết quả:

```text
my-app:1.0
```

---

# 6. Container Registry

Sau khi build Docker image, cần một nơi để lưu image.

Ví dụ:

```text
Jenkins
   │
   │ docker build
   ▼
my-app:1.0
   │
   │ docker push
   ▼
Docker Registry
```

Registry có thể là:

* Docker Hub
* AWS ECR
* GitHub Container Registry
* GitLab Registry
* Nexus Repository

Ví dụ:

```text
Nexus
 └── docker-repository
      ├── my-app:1.0
      ├── my-app:1.1
      └── my-app:1.2
```

**Registry không chạy app.**

Nó chủ yếu:

> **lưu Docker image để server/Kubernetes pull về.**

---

# 7. Deployment — chạy app thật

Đây là bước:

> "Image đã build rồi, giờ chạy nó ở đâu?"

Có nhiều cách.

### Cách 1: Docker trực tiếp

```text
Server
 └── Docker
      └── my-app
```

Chạy:

```bash
docker run my-app:1.0
```

---

### Cách 2: Docker Compose

Ví dụ hệ thống:

```text
docker-compose
│
├── backend
├── frontend
├── postgres
├── redis
└── kafka
```

Phù hợp với:

* development
* staging
* hệ thống nhỏ

---

### Cách 3: Kubernetes

Production lớn thường dùng Kubernetes.

```text
Kubernetes Cluster
│
├── Node
│    ├── Pod backend
│    ├── Pod backend
│    └── Pod frontend
│
├── Node
│    ├── Pod backend
│    └── Pod redis
│
└── Node
     └── Pod kafka
```

Kubernetes chịu trách nhiệm:

* chạy container
* restart container chết
* scale
* service discovery
* rolling update
* load balancing
* health check

---

# 8. Helm — quản lý Kubernetes

Nếu Kubernetes có rất nhiều YAML:

```text
deployment.yaml
service.yaml
configmap.yaml
secret.yaml
ingress.yaml
```

thì Helm giúp quản lý chúng thành một package.

```text
Helm Chart
│
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
│
└── values.yaml
```

Deploy:

```bash
helm install my-app ./my-chart
```

Upgrade:

```bash
helm upgrade my-app ./my-chart
```

Có thể hiểu:

> **Kubernetes = nền tảng chạy app**
> **Helm = công cụ quản lý cách deploy app lên Kubernetes**

---

# 9. Database

Application thường không chạy một mình.

Ví dụ:

```text
Backend
   │
   ├── PostgreSQL
   ├── Redis
   └── Kafka
```

Database có thể là:

* PostgreSQL
* MySQL
* MongoDB
* Oracle

Trong production thường không nên tùy tiện để database cùng container với application.

Ví dụ:

```text
Kubernetes
│
├── Backend
├── Frontend
└── Redis

External Infrastructure
│
└── PostgreSQL
```

Hoặc dùng cloud database.

---

# 10. Redis

Redis thường dùng cho:

```text
Backend
   │
   ▼
 Redis
```

Các mục đích:

* Cache
* Session
* Distributed Lock
* Rate Limiting
* Temporary data

Ví dụ:

```text
Request
   │
   ▼
Backend
   │
   ├── Redis ── HIT → trả data
   │
   └── Database → lấy data
```

---

# 11. Kafka

Nếu hệ thống microservices thì có thể có Kafka:

```text
Order Service
      │
      │ publish
      ▼
    Kafka
      │
      ├──────► Payment Service
      │
      └──────► Notification Service
```

Kafka dùng để:

> **truyền message/event giữa các service một cách bất đồng bộ.**

---

# 12. Monitoring — Prometheus + Grafana

Deploy xong **chưa phải là xong**.

Bạn phải biết:

> App có đang khỏe không?

Prometheus thu thập metrics:

```text
Application
    │
    │ metrics
    ▼
Prometheus
    │
    ▼
Grafana
```

Ví dụ Grafana hiển thị:

```text
CPU        65%
Memory     72%
Requests   1,250/s
Error      2.1%
Latency    120ms
```

Ví dụ:

```text
API /login
   │
   ├── Request: 10,000
   ├── Success: 9,800
   └── Error: 200
```

---

# 13. Logging — ELK

Monitoring trả lời:

> **"Hệ thống đang có vấn đề gì?"**

Logging trả lời:

> **"Chi tiết chuyện gì đã xảy ra?"**

Một stack phổ biến:

```text
Application
     │
     │ logs
     ▼
 Logstash
     │
     ▼
Elasticsearch
     │
     ▼
   Kibana
```

Ví dụ app log:

```text
2026-09-15 10:20:31 ERROR
PaymentService
Payment failed
orderId=123
```

Bạn vào Kibana tìm:

```text
orderId:123
```

để debug.

---

# 14. Alerting

Monitoring mà chỉ nhìn dashboard thì chưa đủ.

Ví dụ:

```text
CPU > 90%
       │
       ▼
Prometheus
       │
       ▼
Alertmanager
       │
       ├── Email
       ├── Slack
       └── PagerDuty
```

Ví dụ:

> 🚨 Backend CPU > 90% trong 5 phút.

DevOps/SRE nhận được cảnh báo.

---

# 15. Security

Production còn cần security.

Pipeline có thể:

```text
Code
 ↓
SAST
 ↓
Dependency Scan
 ↓
Docker Image Scan
 ↓
Deploy
```

Ví dụ:

* SonarQube
* Trivy
* Snyk
* OWASP Dependency Check

Kiểm tra:

```text
Source Code
   ↓
Có vulnerability không?
   ↓
Docker Image
   ↓
Có CVE không?
```

---

# 16. Secrets / Configuration

**Không được hard-code password vào Git.**

❌ Sai:

```yaml
DB_PASSWORD: 123456
```

Nên sử dụng:

```text
Secret Manager
     │
     ├── DB_PASSWORD
     ├── API_KEY
     └── JWT_SECRET
```

Có thể dùng:

* Kubernetes Secret
* AWS Secrets Manager
* HashiCorp Vault
* AWS Parameter Store

---

# 17. Load Balancer / Ingress

Nếu có nhiều instance:

```text
              User
                │
                ▼
          Load Balancer
          /      |      \
         ▼       ▼       ▼
      Backend Backend Backend
```

Load Balancer phân phối request.

Trong Kubernetes có thể có:

```text
Internet
   │
   ▼
Ingress
   │
   ▼
Service
   │
   ├── Pod
   ├── Pod
   └── Pod
```

---

# 18. Một pipeline Production hoàn chỉnh

Nếu gom tất cả lại:

```text
                   DEVELOPER
                       │
                    git push
                       │
                       ▼
                ┌─────────────┐
                │ GitHub/GitLab│
                └──────┬──────┘
                       │
                       ▼
                 ┌───────────┐
                 │  Jenkins  │
                 └─────┬─────┘
                       │
             ┌─────────┼─────────┐
             ▼         ▼         ▼
           Build      Test    SonarQube
             │
             ▼
        Docker Build
             │
             ▼
      Docker Image
             │
             ▼
       ┌───────────┐
       │  Nexus    │
       │ Registry  │
       └─────┬─────┘
             │
             │ pull image
             ▼
      ┌───────────────┐
      │  Kubernetes   │
      │    Cluster    │
      └───────┬───────┘
              │
       ┌──────┼──────┐
       ▼      ▼      ▼
      Pod    Pod    Pod
       │
       ├──────────► PostgreSQL
       ├──────────► Redis
       └──────────► Kafka

              │
       ┌──────┴──────┐
       ▼             ▼
  Prometheus         ELK
       │             │
       ▼             ▼
    Grafana        Kibana
       │
       ▼
    Alertmanager
       │
       ▼
     DevOps
```

## 19. Fresher nên nhớ theo thứ tự này

Đừng cố học tất cả cùng lúc. Hãy hiểu **flow** trước:

```text
1. Git
   ↓
2. Jenkins / CI/CD
   ↓
3. Build
   ↓
4. Docker
   ↓
5. Registry
   ↓
6. Docker Compose
   ↓
7. Kubernetes
   ↓
8. Helm
   ↓
9. Database / Redis / Kafka
   ↓
10. Prometheus + Grafana
   ↓
11. ELK
   ↓
12. Security + Secrets
```

**Câu phỏng vấn quan trọng nhất cần hiểu:**

> **"Developer push code thì làm sao code đó đi từ Git đến Production?"**

Bạn nên trả lời được:

**Git → CI → Build/Test → Docker Image → Registry → Kubernetes → Service/Ingress → Monitoring/Logging → Alert.**

Đây chính là **xương sống của một hệ thống DevOps hiện đại**.
