document.addEventListener('DOMContentLoaded', () => {
    // Check API Health
    fetch('/api/health')
        .then(response => response.json())
        .then(data => {
            const statusEl = document.getElementById('api-status');
            if (data.status === 'healthy') {
                statusEl.textContent = 'API Status: Online 🟢';
                statusEl.style.color = '#4caf50';
            }
        })
        .catch(err => {
            const statusEl = document.getElementById('api-status');
            statusEl.textContent = 'API Status: Offline 🔴';
            statusEl.style.color = '#f44336';
            console.error('API health check failed:', err);
        });

    // Handle Contact Form Submission
    const contactForm = document.getElementById('contact-form');
    const formStatus = document.getElementById('form-status');

    contactForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const name = document.getElementById('name').value;
        const email = document.getElementById('email').value;
        const message = document.getElementById('message').value;

        try {
            const response = await fetch('/api/contact', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ name, email, message })
            });

            if (response.ok) {
                formStatus.textContent = 'Message sent successfully! We will get back to you soon.';
                formStatus.style.color = '#4caf50';
                formStatus.classList.remove('hidden');
                contactForm.reset();
            } else {
                throw new Error('Failed to send message');
            }
        } catch (error) {
            formStatus.textContent = 'Sorry, there was an error sending your message. Please try again later.';
            formStatus.style.color = '#f44336';
            formStatus.classList.remove('hidden');
        }
    });
});
